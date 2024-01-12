# frozen_string_literal: true

require 'declare_schema/extensions/module'

module DeclareSchema
  module Model
    class << self
      def mix_in(base)
        base.singleton_class.prepend ClassMethods unless base.singleton_class < ClassMethods # don't mix in if a base class already did it

        base.class_eval do
          # ignore the model in the migration until somebody sets
          # @include_in_migration via the fields declaration
          inheriting_cattr_reader include_in_migration: false

          # attr_types holds the type class for any attribute reader (i.e. getter
          # method) that returns rich-types
          inheriting_cattr_reader attr_types: HashWithIndifferentAccess.new
          inheriting_cattr_reader attr_order: []

          # field_specs holds FieldSpec objects for every declared
          # field. Note that attribute readers are created (by ActiveRecord)
          # for all fields, so there is also an entry for the field in
          # attr_types. This is redundant but simplifies the implementation
          # and speeds things up a little.
          inheriting_cattr_reader field_specs: HashWithIndifferentAccess.new

          # index_definitions holds IndexDefinition objects for all the declared indexes.
          inheriting_cattr_reader index_definitions: []
          inheriting_cattr_reader ignore_indexes: []
          inheriting_cattr_reader constraint_specs: []

          # table_options holds optional configuration for the create_table statement
          # supported options include :charset and :collation
          inheriting_cattr_reader table_options: HashWithIndifferentAccess.new

          def self.inherited(klass)
            unless klass.field_specs.has_key?(inheritance_column)
              ic = inheritance_column
              declare_schema do
                field(ic, :string, limit: 255, null: true)
              end
              index(ic)
            end
            super
          end
        end
      end
    end

    module ClassMethods
      def index(fields, **options)
        # make index idempotent
        index_fields_s = Array.wrap(fields).map(&:to_s)
        unless index_definitions.any? { |index_spec| index_spec.fields == index_fields_s }
          index_definitions << ::DeclareSchema::Model::IndexDefinition.new(self, fields, **options)
        end
      end

      def primary_key_index(*fields)
        index(fields.flatten, unique: true, name: ::DeclareSchema::Model::IndexDefinition::PRIMARY_KEY_NAME)
      end

      def constraint(fkey, **options)
        fkey_s = fkey.to_s
        unless constraint_specs.any? { |constraint_spec| constraint_spec.foreign_key == fkey_s }
          constraint_specs << DeclareSchema::Model::ForeignKeyDefinition.new(self, fkey, **options)
        end
      end

      # tell the migration generator to ignore the named index. Useful for existing indexes, or for indexes
      # that can't be automatically generated (for example: a prefix index in MySQL)
      def ignore_index(index_name)
        ignore_indexes << index_name.to_s
      end

      # Declare named field with a type and an arbitrary set of
      # arguments. The arguments are forwarded to the #field_added
      # callback, allowing custom metadata to be added to field
      # declarations.
      def declare_field(name, type, *args, **options)
        try(:field_added, name, type, args, options)
        _add_serialize_for_field(name, type, options)
        _add_formatting_for_field(name, type)
        _add_validations_for_field(name, type, args, options)
        _add_index_for_field(name, args, options)
        field_specs[name] = ::DeclareSchema::Model::FieldSpec.new(self, name, type, position: field_specs.size, **options)
        attr_order << name unless attr_order.include?(name)
      end

      def index_definitions_with_primary_key
        if index_definitions.any?(&:primary_key?)
          index_definitions
        else
          index_definitions + [_rails_default_primary_key]
        end
      end

      # Extend belongs_to so that it
      # 1. creates a FieldSpec for the foreign key
      # 2. declares an index on the foreign key
      # 3. declares a foreign_key constraint
      def belongs_to(name, scope = nil, **options)
        column_options = {}

        column_options[:null] = if options.has_key?(:null)
                                  options.delete(:null)
                                elsif options.has_key?(:optional)
                                  options[:optional] # infer :null from :optional
                                end || false
        column_options[:default] = options.delete(:default) if options.has_key?(:default)
        if options.has_key?(:limit)
          options.delete(:limit)
          ActiveSupport::Deprecation.warn("belongs_to limit: is deprecated since it is now inferred")
        end

        # index: true means create an index on the foreign key
        # index: false means do not create an index on the foreign key
        # index: { ... } means create an index on the foreign key with the given options
        index_value = options.delete(:index)
        if index_value != false || options.has_key?(:unique) || options.has_key?(:allow_equivalent)
          index_options = {}
          case index_value
          when String
            Kernel.warn("belongs_to index: 'name' is deprecated; use index: { name: 'name' } instead")
            index_options[:name] = index_value
          # when false -- impossible since we checked that above
          when true
          when nil
          when Hash
            index_options = index_value
          else
            raise ArgumentError, "belongs_to index: must be true or false or a Hash; got #{index_value.inspect}"
          end

          if options.has_key?(:unique)
            Kernel.warn("belongs_to unique: true|false is deprecated; use index: { unique: true|false } instead")
            index_options[:unique] = options.delete(:unique)
          end

          index_options[:allow_equivalent] = options.delete(:allow_equivalent) if options.has_key?(:allow_equivalent)
        end

        fk_options = options.dup
        fk_options[:constraint_name] = options.delete(:constraint) if options.has_key?(:constraint)
        fk_options[:index_name] = index_options&.[](:name)

        fk = options[:foreign_key]&.to_s || "#{name}_id"

        if !options.has_key?(:optional)
          options[:optional] = column_options[:null] # infer :optional from :null
        end

        fk_options[:dependent] = options.delete(:far_end_dependent) if options.has_key?(:far_end_dependent)

        super

        refl = reflections[name.to_s] or raise "Couldn't find reflection #{name} in #{reflections.keys}"
        fkey = refl.foreign_key or raise "Couldn't find foreign_key for #{name} in #{refl.inspect}"
        fkey_id_column_options = column_options.dup

        # Note: the foreign key limit: should match the primary key limit:. (If there is a foreign key constraint,
        # those limits _must_ match.) We'd like to call _infer_fk_limit and get the limit right from the PK.
        # But we can't here, because that will mess up the autoloader to follow every belongs_to association right
        # when it is declared. So instead we assume :bigint (integer limit: 8) below, while also registering this
        # pre_migration: callback to double-check that assumption Just In Time--right before we generate a migration.
        #
        # The one downside of this approach is that application code that asks the field_spec for the declared
        # foreign key limit: will always get 8 back even if this is a grandfathered foreign key that points to
        # a limit: 4 primary key. It seems unlikely that any application code would do this.
        fkey_id_column_options[:pre_migration] = ->(field_spec) do
          if (inferred_limit = _infer_fk_limit(fkey, refl))
            field_spec.sql_options[:limit] = inferred_limit
          end
        end

        declare_field(fkey.to_sym, :bigint, **fkey_id_column_options)

        if refl.options[:polymorphic]
          foreign_type = options[:foreign_type] || "#{name}_type"
          _declare_polymorphic_type_field(foreign_type, column_options)
          index([foreign_type, fkey], **index_options) if index_options
        else
          index(fkey, **index_options) if index_options
          constraint(fkey, **fk_options) if fk_options[:constraint_name] != false
        end
      end

      def _infer_fk_limit(fkey, refl)
        if refl.options[:polymorphic]
          if (fkey_column = columns_hash[fkey.to_s]) && fkey_column.type == :integer
            fkey_column.limit
          end
        else
          klass = refl.klass or raise "Couldn't find belongs_to klass for #{name} in #{refl.inspect}"
          if (pk_id_type = klass._table_options&.[](:id))
            if pk_id_type == :integer
              4
            end
          else
            if klass.table_exists? && (pk_column = klass.columns_hash[klass._declared_primary_key])
              pk_id_type = pk_column.type
              if pk_id_type == :integer
                pk_column.limit
              end
            end
          end
        end
      end

      # returns the primary key (String) as declared with primary_key =
      # unlike the `primary_key` method, DOES NOT query the database to find the actual primary key in use right now
      # if no explicit primary key set, returns the _default_declared_primary_key
      def _declared_primary_key
        if defined?(@primary_key)
          @primary_key&.to_s
        end || _default_declared_primary_key
      end

      private

      # if this is a derived class, returns the base class's _declared_primary_key
      # otherwise, returns 'id'
      def _default_declared_primary_key
        if self == base_class
          'id'
        else
          base_class._declared_primary_key
        end
      end

      def _rails_default_primary_key
        ::DeclareSchema::Model::IndexDefinition.new(self, [_declared_primary_key.to_sym], unique: true, name: DeclareSchema::Model::IndexDefinition::PRIMARY_KEY_NAME)
      end

      # Declares the "foo_type" field that accompanies the "foo_id"
      # field for a polymorphic belongs_to
      def _declare_polymorphic_type_field(foreign_type, column_options)
        declare_field(foreign_type, :string, **column_options.merge(limit: 255))
        # FIXME: Before declare_schema was extracted, this used to now do:
        # never_show(type_col)
        # That needs doing somewhere
      end

      # Add field validations according to arguments in the
      # field declaration
      def _add_validations_for_field(name, type, args, options)
        validates_presence_of   name if :required.in?(args)
        validates_uniqueness_of name, allow_nil: !:required.in?(args) if :unique.in?(args)

        if (validates_options = options[:validates])
          validates(name, **validates_options)
        end

        # Support for custom validations
        if (type_class = DeclareSchema.to_class(type))
          if type_class.public_method_defined?("validate")
            validate do |record|
              v = record.send(name)&.validate
              record.errors.add(name, v) if v.is_a?(String)
            end
          end
        end
      end

      def _add_serialize_for_field(name, type, options)
        if (serialize_class = options.delete(:serialize))
          type == :string || type == :text or raise ArgumentError, "serialize field type must be :string or :text"
          serialize_args = Array((serialize_class unless serialize_class == true))
          serialize(name, *serialize_args)
          if options.has_key?(:default)
            options[:default] = _serialized_default(name, serialize_class == true ? Object : serialize_class, options[:default])
          end
        end
      end

      def _serialized_default(attr_name, class_name_or_coder, default)
        # copied from https://github.com/rails/rails/blob/7d6cb950e7c0e31c2faaed08c81743439156c9f5/activerecord/lib/active_record/attribute_methods/serialization.rb#L70-L76
        coder = if class_name_or_coder == ::JSON
                  ActiveRecord::Coders::JSON
                elsif [:load, :dump].all? { |x| class_name_or_coder.respond_to?(x) }
                  class_name_or_coder
                else
                  ActiveRecord::Coders::YAMLColumn.new(attr_name, class_name_or_coder)
                end

        if default == coder.load(nil)
          nil # handle Array default: [] or Hash default: {}
        else
          coder.dump(default)
        end
      end

      def _add_formatting_for_field(name, type)
        if (type_class = DeclareSchema.to_class(type))
          if "format".in?(type_class.instance_methods)
            before_validation do |record|
              record.send("#{name}=", record.send(name)&.format)
            end
          end
        end
      end

      def _add_index_for_field(name, args, options)
        if (to_name = options.delete(:index))
          index_opts =
            {
              unique: args.include?(:unique) || options.delete(:unique)
            }
          # support index: true declaration
          index_opts[:name] = to_name unless to_name == true
          index(name, **index_opts)
        end
      end

      # Returns the type (a class) for a given field or association. If
      # the association is a collection (has_many or habtm) return the
      # AssociationReflection instead
      public \
      def attr_type(name)
        if attr_types.nil? && self != self.name.constantize
          raise "attr_types called on a stale class object (#{self.name}). Avoid storing persistent references to classes"
        end

        attr_types[name] ||
          if (refl = reflections[name.to_s])
            if refl.macro.in?([:has_one, :belongs_to]) && !refl.options[:polymorphic]
              refl.klass
            else
              refl
            end
          end ||
          if (col = _column(name.to_s))
            DeclareSchema::PLAIN_TYPES[col.type] || col.klass
          end
      end

      # Return the entry from #columns for the named column
      def _column(name)
        defined?(@table_exists) or @table_exists = table_exists?
        if @table_exists
          columns_hash[name.to_s]
        end
      end
    end
  end
end
