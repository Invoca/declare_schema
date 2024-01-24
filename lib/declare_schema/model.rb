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
          inheriting_cattr_reader index_definitions: Set.new
          inheriting_cattr_reader ignore_indexes: Set.new
          inheriting_cattr_reader constraint_definitions: Set.new

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
      def index(columns, name: nil, allow_equivalent: false, unique: false, where: nil, length: nil)
        index_definition = ::DeclareSchema::Model::IndexDefinition.new(
          columns,
          name: name, table_name: table_name, allow_equivalent: allow_equivalent, unique: unique, where: where, length: length
        )

        if (equivalent = index_definitions.find { index_definition.equivalent?(_1) }) # differs only by name
          if equivalent == index_definition
            # identical is always idempotent
          else
            # equivalent is idempotent iff allow_equivalent: true passed
            allow_equivalent or
              raise ArgumentError, "equivalent index definition found (pass allow_equivalent: true to ignore):\n" \
                                   "#{index_definition.inspect}\n#{equivalent.inspect}"
          end
        else
          index_definitions << index_definition
        end
      end

      def primary_key_index(*columns)
        index(columns.flatten, unique: true, name: ::DeclareSchema::Model::IndexDefinition::PRIMARY_KEY_NAME)
      end

      def constraint(foreign_key_column, parent_table_name: nil, constraint_name: nil, parent_class_name: nil, dependent: nil)
        constraint_definition = ::DeclareSchema::Model::ForeignKeyDefinition.new(
          foreign_key_column.to_s,
          constraint_name: constraint_name,
          child_table_name: table_name, parent_table_name: parent_table_name, parent_class_name: parent_class_name, dependent: dependent
        )

        constraint_definitions << constraint_definition # Set<> implements idempotent insert.
      end

      # tell the migration generator to ignore the named index. Useful for existing indexes, or for indexes
      # that can't be automatically generated.
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
        _add_index_for_field(name, args, **options)
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
      # 2. declares an index on the foreign key (optional)
      # 3. declares a foreign_key constraint (optional)
      def belongs_to(name, scope = nil, **options)
        if options[:null].in?([true, false]) && options[:optional] == options[:null]
          STDERR.puts("[declare_schema warning] belongs_to #{name.inspect}, null: with the same value as optional: is redundant; omit null: #{options[:null]} (called from #{caller[0]})")
        elsif !options.has_key?(:optional)
          case options[:null]
          when true
            STDERR.puts("[declare_schema] belongs_to #{name.inspect}, null: true is deprecated in favor of optional: true (called from #{caller[0]})")
          when false
            STDERR.puts("[declare_schema] belongs_to #{name.inspect}, null: false is implied and can be omitted (called from #{caller[0]})")
          end
        end

        column_options = {}

        column_options[:null] = if options.has_key?(:null)
                                  options.delete(:null)
                                elsif options.has_key?(:optional)
                                  options[:optional] # infer :null from :optional
                                end || false
        column_options[:default] = options.delete(:default) if options.has_key?(:default)
        if options.has_key?(:limit)
          options.delete(:limit)
          ActiveSupport::Deprecation.warn("belongs_to #{name.inspect}, limit: is deprecated since it is now inferred")
        end

        # index: true means create an index on the foreign key
        # index: false means do not create an index on the foreign key
        # index: { ... } means create an index on the foreign key with the given options
        index_value = options.delete(:index)
        if index_value == false # don't create an index
          options.delete(:unique)
          options.delete(:allow_equivalent)
        else
          index_options = {} # create an index
          case index_value
          when String, Symbol
            ActiveSupport::Deprecation.warn("[declare_schema] belongs_to #{name.inspect}, index: 'name' is deprecated; use index: { name: 'name' } instead (in #{self.name})")
            index_options[:name] = index_value.to_s
          when true
          when nil
          when Hash
            index_options = index_value
          else
            raise ArgumentError, "[declare_schema] belongs_to #{name.inspect}, index: must be true or false or a Hash; got #{index_value.inspect} (in #{self.name})"
          end

          if options.has_key?(:unique)
            ActiveSupport::Deprecation.warn("[declare_schema] belongs_to #{name.inspect}, unique: true|false is deprecated; use index: { unique: true|false } instead (in #{self.name})")
            index_options[:unique] = options.delete(:unique)
          end

          index_options[:allow_equivalent] = options.delete(:allow_equivalent) if options.has_key?(:allow_equivalent)
        end

        constraint_name = options.delete(:constraint)

        dependent_delete = :delete if options.delete(:far_end_dependent) == :delete

        # infer :optional from :null
        if !options.has_key?(:optional)
          options[:optional] = column_options[:null]
        end

        super

        reflection = reflections[name.to_s] or raise "Couldn't find reflection #{name} in #{reflections.keys}"
        foreign_key_column = reflection.foreign_key or raise "Couldn't find foreign_key for #{name} in #{reflection.inspect}"
        foreign_key_column_options = column_options.dup

        # Note: the foreign key limit: should match the primary key limit:. (If there is a foreign key constraint,
        # those limits _must_ match.) We'd like to call _infer_fk_limit and get the limit right from the PK.
        # But we can't here, because that will mess up the autoloader to follow every belongs_to association right
        # when it is declared. So instead we assume :bigint (integer limit: 8) below, while also registering this
        # pre_migration: callback to double-check that assumption Just In Time--right before we generate a migration.
        #
        # The one downside of this approach is that application code that asks the field_spec for the declared
        # foreign key limit: will always get 8 back even if this is a grandfathered foreign key that points to
        # a limit: 4 primary key. It seems unlikely that any application code would do this.
        foreign_key_column_options[:pre_migration] = ->(field_spec) do
          if (inferred_limit = _infer_fk_limit(foreign_key_column, reflection))
            field_spec.sql_options[:limit] = inferred_limit
          end
        end

        declare_field(foreign_key_column.to_sym, :bigint, **foreign_key_column_options)

        if reflection.options[:polymorphic]
          foreign_type = options[:foreign_type] || "#{name}_type"
          _declare_polymorphic_type_field(foreign_type, column_options)
          if ::DeclareSchema.default_generate_indexing && index_options
            index([foreign_type, foreign_key_column], **index_options)
          end
        else
          if ::DeclareSchema.default_generate_indexing && index_options
            index([foreign_key_column], **index_options)
          end

          if ::DeclareSchema.default_generate_foreign_keys && constraint_name != false
            constraint(foreign_key_column, constraint_name: constraint_name || index_options&.[](:name), parent_class_name: reflection.class_name, dependent: dependent_delete)
          end
        end
      end

      def _infer_fk_limit(foreign_key_column, reflection)
        if reflection.options[:polymorphic]
          if (foreign_key_column = columns_hash[foreign_key_column.to_s]) && foreign_key_column.type == :integer
            foreign_key_column.limit
          end
        else
          klass = reflection.klass or raise "Couldn't find belongs_to klass for #{name} in #{reflection.inspect}"
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
        ::DeclareSchema::Model::IndexDefinition.new([_declared_primary_key], name: DeclareSchema::Model::IndexDefinition::PRIMARY_KEY_NAME, table_name: table_name, unique: true)
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

      def _add_index_for_field(column_name, args, **options)
        if (index_name = options.delete(:index))
          index_opts =
            {
              unique: args.include?(:unique) || !!options.delete(:unique)
            }

          # support index: true declaration
          index_opts[:name] = index_name unless index_name == true
          index([column_name], **index_opts)
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
          if (reflection = reflections[name.to_s])
            if reflection.macro.in?([:has_one, :belongs_to]) && !reflection.options[:polymorphic]
              reflection.klass
            else
              reflection
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
