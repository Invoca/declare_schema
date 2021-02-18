# frozen_string_literal: true

require 'rails'

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

          # eval avoids the ruby 1.9.2 "super from singleton method ..." error

          eval %(
            def self.inherited(klass)
              unless klass.field_specs.has_key?(inheritance_column)
                fields do |f|
                  f.field(inheritance_column, :string, limit: 255, null: true)
                end
                index(inheritance_column)
              end
              super
            end
          )
        end
      end
    end

    module ClassMethods
      def index(fields, options = {})
        # don't double-index fields
        index_fields_s = Array.wrap(fields).map(&:to_s)
        unless index_definitions.any? { |index_spec| index_spec.fields == index_fields_s }
          index_definitions << ::DeclareSchema::Model::IndexDefinition.new(self, fields, options)
        end
      end

      def primary_key_index(*fields)
        index(fields.flatten, unique: true, name: ::DeclareSchema::Model::IndexDefinition::PRIMARY_KEY_NAME)
      end

      def constraint(fkey, options = {})
        fkey_s = fkey.to_s
        unless constraint_specs.any? { |constraint_spec| constraint_spec.foreign_key == fkey_s }
          constraint_specs << DeclareSchema::Model::ForeignKeyDefinition.new(self, fkey, options)
        end
      end

      # tell the migration generator to ignore the named index. Useful for existing indexes, or for indexes
      # that can't be automatically generated (for example: an prefix index in MySQL)
      def ignore_index(index_name)
        ignore_indexes << index_name.to_s
      end

      # Declare named field with a type and an arbitrary set of
      # arguments. The arguments are forwarded to the #field_added
      # callback, allowing custom metadata to be added to field
      # declarations.
      def declare_field(name, type, *args, **options)
        try(:field_added, name, type, args, options)
        add_serialize_for_field(name, type, options)
        add_formatting_for_field(name, type)
        add_validations_for_field(name, type, args, options)
        add_index_for_field(name, args, options)
        field_specs[name] = ::DeclareSchema::Model::FieldSpec.new(self, name, type, position: field_specs.size, **options)
        attr_order << name unless attr_order.include?(name)
      end

      def index_definitions_with_primary_key
        if index_definitions.any?(&:primary_key?)
          index_definitions
        else
          index_definitions + [rails_default_primary_key]
        end
      end

      if ::Rails::VERSION::MAJOR < 5
        def primary_key
          super || 'id'
        end
      end

      # returns the primary key (String) as declared with primary_key =
      # unlike the `primary_key` method, DOES NOT query the database to find the actual primary key in use right now
      # if no explicit primary key set, returns the default_defined_primary_key
      def defined_primary_key
        if defined?(@primary_key)
          @primary_key&.to_s
        end || default_defined_primary_key
      end

      # if this is a derived class, returns the base class's defined_primary_key
      # otherwise, returns 'id'
      def default_defined_primary_key
        if self == base_class
          'id'
        else
          base_class.defined_primary_key
        end
      end

      private

      def rails_default_primary_key
        ::DeclareSchema::Model::IndexDefinition.new(self, [primary_key.to_sym], unique: true, name: DeclareSchema::Model::IndexDefinition::PRIMARY_KEY_NAME)
      end

      # Extend belongs_to so that it creates a FieldSpec for the foreign key
      def belongs_to(name, scope = nil, **options)
        column_options = {}

        column_options[:null] = if options.has_key?(:null)
                                  options.delete(:null)
                                elsif options.has_key?(:optional)
                                  options[:optional] # infer :null from :optional
                                end || false
        column_options[:default] = options.delete(:default) if options.has_key?(:default)
        column_options[:limit] = options.delete(:limit) if options.has_key?(:limit)

        index_options = {}
        index_options[:name]   = options.delete(:index) if options.has_key?(:index)
        index_options[:unique] = options.delete(:unique) if options.has_key?(:unique)
        index_options[:allow_equivalent] = options.delete(:allow_equivalent) if options.has_key?(:allow_equivalent)

        fk_options = options.dup
        fk_options[:constraint_name] = options.delete(:constraint) if options.has_key?(:constraint)
        fk_options[:index_name] = index_options[:name]

        fk = options[:foreign_key]&.to_s || "#{name}_id"

        if !options.has_key?(:optional)
          options[:optional] = column_options[:null] # infer :optional from :null
        end

        fk_options[:dependent] = options.delete(:far_end_dependent) if options.has_key?(:far_end_dependent)

        if Rails::VERSION::MAJOR >= 5
          super
        else
          super(name, scope, options.except(:optional))
        end

        refl = reflections[name.to_s] or raise "Couldn't find reflection #{name} in #{reflections.keys}"
        fkey = refl.foreign_key or raise "Couldn't find foreign_key for #{name} in #{refl.inspect}"
        declare_field(fkey.to_sym, :integer, column_options)
        if refl.options[:polymorphic]
          foreign_type = options[:foreign_type] || "#{name}_type"
          declare_polymorphic_type_field(foreign_type, column_options)
          index([foreign_type, fkey], index_options) if index_options[:name] != false
        else
          index(fkey, index_options) if index_options[:name] != false
          constraint(fkey, fk_options) if fk_options[:constraint_name] != false
        end
      end

      # Declares the "foo_type" field that accompanies the "foo_id"
      # field for a polymorphic belongs_to
      def declare_polymorphic_type_field(foreign_type, column_options)
        declare_field(foreign_type, :string, column_options.merge(limit: 255))
        # FIXME: Before declare_schema was extracted, this used to now do:
        # never_show(type_col)
        # That needs doing somewhere
      end

      # Declare a rich-type for any attribute (i.e. getter method). This
      # does not effect the attribute in any way - it just records the
      # metadata.
      def declare_attr_type(name, type, options = {})
        attr_types[name] = klass = DeclareSchema.to_class(type)
        klass.try(:declared, self, name, options)
      end

      # Add field validations according to arguments in the
      # field declaration
      def add_validations_for_field(name, type, args, options)
        validates_presence_of   name if :required.in?(args)
        validates_uniqueness_of name, allow_nil: !:required.in?(args) if :unique.in?(args)

        if (validates_options = options[:validates])
          validates name, validates_options
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

      def add_serialize_for_field(name, type, options)
        if (serialize_class = options.delete(:serialize))
          type == :string || type == :text or raise ArgumentError, "serialize field type must be :string or :text"
          serialize_args = Array((serialize_class unless serialize_class == true))
          serialize(name, *serialize_args)
          if options.has_key?(:default)
            options[:default] = serialized_default(name, serialize_class == true ? Object : serialize_class, options[:default])
          end
        end
      end

      def serialized_default(attr_name, class_name_or_coder, default)
        # copied from https://github.com/rails/rails/blob/7d6cb950e7c0e31c2faaed08c81743439156c9f5/activerecord/lib/active_record/attribute_methods/serialization.rb#L70-L76
        coder = if class_name_or_coder == ::JSON
                  ActiveRecord::Coders::JSON
                elsif [:load, :dump].all? { |x| class_name_or_coder.respond_to?(x) }
                  class_name_or_coder
                elsif Rails::VERSION::MAJOR >= 5
                  ActiveRecord::Coders::YAMLColumn.new(attr_name, class_name_or_coder)
                else
                  ActiveRecord::Coders::YAMLColumn.new(class_name_or_coder)
                end

        if default == coder.load(nil)
          nil # handle Array default: [] or Hash default: {}
        else
          coder.dump(default)
        end
      end

      def add_formatting_for_field(name, type)
        if (type_class = DeclareSchema.to_class(type))
          if "format".in?(type_class.instance_methods)
            before_validation do |record|
              record.send("#{name}=", record.send(name)&.format)
            end
          end
        end
      end

      def add_index_for_field(name, args, options)
        if (to_name = options.delete(:index))
          index_opts =
            {
              unique: args.include?(:unique) || options.delete(:unique)
            }
          # support index: true declaration
          index_opts[:name] = to_name unless to_name == true
          index(name, index_opts)
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
          if (col = column(name.to_s))
            DeclareSchema::PLAIN_TYPES[col.type] || col.klass
          end
      end

      # Return the entry from #columns for the named column
      def column(name)
        defined?(@table_exists) or @table_exists = table_exists?
        if @table_exists
          columns_hash[name.to_s]
        end
      end
    end
  end
end
