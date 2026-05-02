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
      def index(columns, name: nil, allow_equivalent: true, ignore_equivalent_definitions: false, unique: false, where: nil, length: nil)
        index_definition = ::DeclareSchema::Model::IndexDefinition.new(
          columns,
          name: name, table_name: table_name, allow_equivalent: allow_equivalent, unique: unique, where: where, length: length
        )

        if (equivalent = index_definitions.find { index_definition.equivalent?(_1) }) # differs only by name
          if equivalent == index_definition
            # identical is always idempotent
          else
            # equivalent is idempotent iff ignore_equivalent_definitions: true passed
            ignore_equivalent_definitions or
              raise ArgumentError, "equivalent index definition found (pass ignore_equivalent_definitions: true to ignore):\n" \
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
        _add_scopes_for_field(name, type, **options)
        name.to_s == _declared_primary_key and raise ArgumentError, "no need to declare a field spec for the primary key #{name.inspect}"
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
      # @param name [Symbol] the name of the association to pass to super
      # @param scope [Proc] the scope of the association to pass to super
      # @option options [Boolean] :optional (default: false) whether the foreign key column should be nullable and whether
      #   ActiveRecord should validate presence of the foreign key (passed through to super)
      # @option options [Boolean] :null (default: inferred from options[:optional]) whether the foreign key column should be nullable
      #   (`null:` should only be passed if it is the inverse of `optional:`; otherwise it is redundant)
      # @option options [Integer] :limit (default: inferred from the primary key limit:) the limit of the foreign key column size (4 or 8)
      # @option options [Boolean|Hash<Symbol>] :index (default: true) whether to create an index on the foreign key; can be true or false
      #   or a hash of options to pass to the index declaration, with keys like { name: ..., unique: ... }
      # @option options [Boolean] :allow_equivalent (default: false) whether to allow an existing index with a different name
      # @option options [Boolean|String] :constraint (default: true) whether to create a foreign key constraint on the foreign key;
      #   may be true or false or a string to use as the constraint name
      # @option options [Boolean] :polymorphic (default: false) whether this is a polymorphic belongs_to with a _type column next to
      #   the foreign key _id column (also passed through to super)
      # @option options [Boolean] :far_end_dependent (default: nil) whether to add a dependent: :delete to the far end of the foreign key
      #   constraint
      # @option options [String] :foreign_type (default: "#{name}_type") the name prefix for the _type column for a polymorphic belongs_to
      #   (passed through to super)
      # Other options are passed through to super
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
          limit = options.delete(:limit)
          DeclareSchema.deprecator.warn("belongs_to #{name.inspect}, limit: #{limit} is deprecated since it is now inferred")
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
            DeclareSchema.deprecator.warn("[declare_schema] belongs_to #{name.inspect}, index: 'name' is deprecated; use index: { name: 'name' } instead (in #{self.name})")
            index_options[:name] = index_value.to_s
          when true
          when nil
          when Hash
            index_options = index_value
          else
            raise ArgumentError, "[declare_schema] belongs_to #{name.inspect}, index: must be true or false or a Hash; got #{index_value.inspect} (in #{self.name})"
          end

          if options.has_key?(:unique)
            DeclareSchema.deprecator.warn("[declare_schema] belongs_to #{name.inspect}, unique: true|false is deprecated; use index: { unique: true|false } instead (in #{self.name})")
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
        foreign_key_column_name = reflection.foreign_key or raise "Couldn't find foreign_key for #{name} in #{reflection.inspect}"

        field_specs[foreign_key_column_name] = _infer_foreign_key_field_spec(foreign_key_column_name, reflection, column_options)

        if reflection.options[:polymorphic]
          foreign_type = options[:foreign_type] || "#{name}_type"
          _declare_polymorphic_type_field(foreign_type, column_options)
          if ::DeclareSchema.default_generate_indexing && index_options
            index([foreign_type, foreign_key_column_name], **index_options)
          end
        else
          if ::DeclareSchema.default_generate_indexing && index_options
            index([foreign_key_column_name], **index_options)
          end

          if ::DeclareSchema.default_generate_foreign_keys && constraint_name != false
            constraint(foreign_key_column_name,
                       constraint_name: constraint_name || index_options&.[](:name),
                       parent_class_name: reflection.class_name,
                       dependent: dependent_delete)
          end
        end
      end

      # Returns a FieldSpec for the foreign key column of a belongs_to association.
      # - For a polymorphic association, the FK uses `DeclareSchema.default_generated_primary_key_type`
      #   (mirroring `config.generators.primary_key_type`, default :bigint), or :integer with the
      #   existing column's limit if the column already exists in the database.
      # - For a non-polymorphic association, the FK should mirror the primary key it points
      #   at (same data type, same options like limit:, charset:, etc.). However we cannot
      #   load the parent model right now (at `belongs_to` time) without risking dependency
      #   cycles between models, so we install a `resolver:` callback. The migration
      #   generator calls that resolver at generation time -- after all models are
      #   eager-loaded -- and the resolver returns a fully-mirrored FieldSpec that the
      #   generator swaps in for this placeholder.
      def _infer_foreign_key_field_spec(foreign_key_column_name, reflection, column_options)
        if reflection.options[:polymorphic]
          if (foreign_key_column = _column(foreign_key_column_name)) && foreign_key_column.type == :integer
            # grandfather foreign key column to match what's in the database
            column_options = column_options.merge(limit: foreign_key_column.limit)
          end
          FieldSpec.new(self, foreign_key_column_name, DeclareSchema.default_generated_primary_key_type, position: field_specs.size, **column_options)
        else
          # Capture only what we need from `reflection` (no `reflection.klass` here -- that
          # would force the parent model to load, which is exactly the cycle we are avoiding).
          # `reflection.klass` is resolved lazily inside the block below.
          resolver = ->(placeholder) do
            _resolve_belongs_to_foreign_key_field_spec(reflection, placeholder)
          end
          FieldSpec.new(self, foreign_key_column_name, DeclareSchema.default_generated_primary_key_type,
                        position: field_specs.size, resolver:, **column_options)
        end
      end

      # Called at migration generation time to mirror the parent model's primary key.
      # Always returns a FieldSpec: the placeholder unchanged when the parent class is not
      # a declare_schema model (we can't ask for its PK spec, so the placeholder's configured
      # default PK type is the best we can offer without inspecting the DB), otherwise a fully
      # mirrored FieldSpec.
      #
      # Reconciliation with the live DB: if the parent's PK column already exists in the
      # database with the same Rails type but a different :limit (e.g. a legacy table where
      # `id` is INT(4) but the model now declares the default :bigint), prefer the live
      # column's :limit so the FK matches what's actually on disk. This preserves the
      # behavior of the old DB-column lookup (formerly `fk_field_options`) without
      # overriding intentional type changes.
      def _resolve_belongs_to_foreign_key_field_spec(reflection, placeholder)
        klass = reflection.klass or
          raise "Couldn't find belongs_to klass for #{reflection.name} on #{name} in #{reflection.inspect}"

        if klass.respond_to?(:_primary_key_field_spec)
          _mirror_parent_primary_key(klass, placeholder)
        else
          placeholder
        end
      end

      # Build a FieldSpec for the FK by mirroring the parent's declared primary key,
      # then reconciling against the live DB column when it differs only in :limit
      # (see _resolve_belongs_to_foreign_key_field_spec for the full rationale).
      def _mirror_parent_primary_key(klass, placeholder)
        spec = klass._primary_key_field_spec.foreign_key_field_spec(
          placeholder.model, placeholder.name,
          position: placeholder.position, null: placeholder.null
        )

        # Look up the parent's live PK column directly (not via _column, whose
        # @table_exists memoization can pin to a stale value when the parent table
        # is created after the model class is first defined). The rescue covers
        # the table-doesn't-exist-yet case (greenfield migration).
        live_pk_column = klass.columns_hash[klass._declared_primary_key.to_s] rescue nil
        if live_pk_column && live_pk_column.type == spec.type && live_pk_column.limit && live_pk_column.limit != spec.limit
          FieldSpec.new(
            spec.model, spec.name, spec.type,
            position: spec.position,
            **spec.options.merge(limit: live_pk_column.limit)
          )
        else
          spec
        end
      end

      # returns the primary key (String) as declared with primary_key =
      # unlike the `primary_key` method, DOES NOT query the database to find the actual primary key in use right now
      # if no explicit primary key set, returns the _default_declared_primary_key
      def _declared_primary_key
        if !defined?(@primary_key) ||
           (ActiveSupport.version >= Gem::Version.new('7.1.0') &&
             @primary_key == ActiveRecord::AttributeMethods::PrimaryKey::ClassMethods::PRIMARY_KEY_NOT_SET)
          _default_declared_primary_key
        else
          @primary_key&.to_s
        end
      end

      # Returns a FieldSpec for a foreign key pointing to the primary key of this model.
      # Exactly matches the primary key type.
      def _foreign_key_field_spec(model, foreign_key, position:, null:)
        _primary_key_field_spec.foreign_key_field_spec(model, foreign_key, position:, null:)
      end

      def _primary_key_field_spec
        declared_primary_key = _declared_primary_key
        field_specs[declared_primary_key] || _primary_key_field_spec_from_table_options(declared_primary_key) or
          raise "Declared primary key #{declared_primary_key.inspect} not found in field_specs or _table_options #{_table_options.inspect} for #{name}"
      end

      def _primary_key_field_spec_from_table_options(declared_primary_key)
        type, options = _parse_pk_table_options(_table_options[declared_primary_key.to_sym] || _table_options[declared_primary_key])
        type ||= DeclareSchema.default_generated_primary_key_type
        FieldSpec.new(self, declared_primary_key, type, **options)
      end

      private

      # `declare_schema id: ...` accepts either a Hash (`id: { type: :integer, limit: 4 }`)
      # or a bare type Symbol (`id: :integer`). Returns [type, options_hash], with type == nil
      # when value is neither (caller falls back to a default).
      def _parse_pk_table_options(value)
        case value
        when Hash   then [value[:type], value.except(:type)]
        when Symbol then [value, {}]
        else             [nil, {}]
        end
      end

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
          if type_class.public_method_defined?("validate") && type_class.instance_method("validate").arity.zero?
            validate do |record|
              v = record.send(name)&.validate
              record.errors.add(name, v) if v.is_a?(String)
            end
          end
        end
      end

      def _add_scopes_for_field(field_name, field_type, options)
        if field_type == :enum && options[:scopes]
          scope_prefix = options[:scopes].is_a?(Hash) ? options[:scopes][:prefix] : nil
          options[:limit].each do |enum_value|
            scope_name = scope_prefix ? "#{scope_prefix}_#{enum_value}" : enum_value
            scope scope_name, -> { where(field_name => enum_value) }
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
        if (type_class = DeclareSchema.to_class(type)) && "format".in?(type_class.instance_methods)
          before_validation do |record|
            record.send("#{name}=", record.send(name)&.format)
          end
        end
      end

      def _add_index_for_field(column_name, args, **options)
        if (index_config = options.delete(:index))
          index_opts = index_config.is_a?(Hash) ? index_config : {}
          index_opts[:unique] ||= args.include?(:unique) || !!options.delete(:unique)

          # support index: true declaration
          index_opts[:name] = index_config unless index_config == true || index_config.is_a?(Hash)
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
