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

          # index_specs holds IndexSpec objects for all the declared indexes.
          inheriting_cattr_reader index_specs: []
          inheriting_cattr_reader ignore_indexes: []
          inheriting_cattr_reader constraint_specs: []

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
        unless index_specs.any? { |index_spec| index_spec.fields == index_fields_s }
          index_specs << ::DeclareSchema::Model::IndexSettings.new(self, fields, options)
        end
      end

      def primary_key_index(*fields)
        index(fields.flatten, unique: true, name: "PRIMARY_KEY")
      end

      def constraint(fkey, options = {})
        fkey_s = fkey.to_s
        unless constraint_specs.any? { |constraint_spec| constraint_spec.foreign_key == fkey_s }
          constraint_specs << DeclareSchema::Model::ForeignKeySettings.new(self, fkey, options)
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
      def declare_field(name, type, *args)
        options = args.extract_options!
        field_added(name, type, args, options) if respond_to?(:field_added)
        add_formatting_for_field(name, type, args)
        add_validations_for_field(name, type, args, options)
        add_index_for_field(name, args, options)
        field_specs[name] = ::DeclareSchema::Model::FieldSpec.new(self, name, type, options)
        attr_order << name unless name.in?(attr_order)
      end

      def index_specs_with_primary_key
        if index_specs.any?(&:primary_key?)
          index_specs
        else
          index_specs + [rails_default_primary_key]
        end
      end

      def primary_key
        super || 'id'
      end

      private

      def rails_default_primary_key
        ::DeclareSchema::Model::IndexSettings.new(self, [primary_key.to_sym], unique: true, name: DeclareSchema::Model::IndexSettings::PRIMARY_KEY_NAME)
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
        klass = DeclareSchema.to_class(type)
        attr_types[name] = DeclareSchema.to_class(type)
        klass.declared(self, name, options) if klass.respond_to?(:declared)
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

      def add_formatting_for_field(name, type, _args)
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
