module HoboFields
  module Model

    class IndexSpec
      include Comparable

      attr_accessor :table, :fields, :name, :unique

      def initialize(model, fields, options={})
        @model = model
        self.table = options.delete(:table_name) || model.table_name
        self.fields = Array.wrap(fields).*.to_s
        self.name = options.delete(:name) || model.connection.index_name(self.table, :column => self.fields)
        self.unique = options.delete(:unique) || false
        @name = options[:name] if options[:name]
      end

      # extract IndexSpecs from an existing table
      def self.for_model(model, old_table_name=nil)
        t = old_table_name || model.table_name
        model.connection.indexes(t).map do |i|
          self.new(model, i.columns, :name => i.name, :unique => i.unique, :table_name => old_table_name) unless model.ignore_indexes.include?(i.name)
        end.compact
      end

      def default_name?
        name == @model.connection.index_name(table, :column => fields)
      end

      def to_add_statement(new_table_name)
        r = "add_index :#{new_table_name}, #{fields.*.to_sym.inspect}"
        r += ", :unique => true" if unique
        r += ", :name => '#{name}'" unless default_name?
        r
      end

      def to_key
        @key ||= [table, fields, name, unique].map { |key| key.to_s }
      end

      def hash
        to_key.hash
      end

      def <=>(rhs)
        to_key <=> rhs.to_key
      end

      alias_method :eql?, :==

    end

    class ForeignKeySpec
      include Comparable

      attr_reader :constraint_name, :model, :foreign_key, :options, :on_delete_cascade

      def initialize(model, foreign_key, options={})
        @model = model
        @foreign_key = foreign_key
        @options = options

        @child_table = model.table_name #unless a table rename, which would happen when a class is renamed??
        @parent_table_name = options[:parent_table]
        @foreign_key_name = options[:foreign_key] || self.foreign_key
        @index_name = options[:index_name] || model.connection.index_name(model.table_name, :column => foreign_key)
        @constraint_name = options[:constraint_name] || @index_name || ''
        @on_delete_cascade = options[:dependent] == :delete

        #Empty constraint lets mysql generate the name
      end

      def self.for_model(model, old_table_name = nil)
        show_create_table = model.connection.select_rows("show create table #{model.connection.quote_table_name(model.table_name)}").first.last
        constraints = show_create_table.split("\n").map { |line| line.strip if line['CONSTRAINT'] }.compact

        constraints.map do |fkc|
          options = {}
          name, foreign_key, parent_table = fkc.match(/CONSTRAINT `([^`]*)` FOREIGN KEY \(`([^`]*)`\) REFERENCES `([^`]*)`/).captures
          options[:constraint_name] = name
          options[:parent_table] = parent_table
          options[:foreign_key] = foreign_key
          options[:dependent] = :delete if fkc['ON DELETE CASCADE']

          self.new(model, foreign_key, options)
        end
      end

      def parent_table_name
        @parent_table_name ||=
          options[:class_name] &&
          options[:class_name].is_a?(Class) &&
          options[:class_name].respond_to?(:table_name) &&
          options[:class_name].table_name
        @parent_table_name ||=
          options[:class_name] &&
          options[:class_name].constantize &&
          options[:class_name].constantize.respond_to?(:table_name) &&
          options[:class_name].constantize.table_name ||
          foreign_key.gsub(/_id/, '').camelize.constantize.table_name
      end

      def parent_table_name=(name)
        @parent_table_name = name
      end

      def to_add_statement(unused = true)
        %Q{execute "ALTER TABLE #{@child_table} ADD CONSTRAINT #{@constraint_name} FOREIGN KEY #{@index_name}(#{@foreign_key_name}) REFERENCES #{parent_table_name}(id) #{'ON DELETE CASCADE' if on_delete_cascade}"}
      end

      def to_key
        @key ||= [@child_table, parent_table_name, @foreign_key_name, @on_delete_cascade].map { |key| key.to_s }
      end

      def hash
        to_key.hash
      end

      def <=>(rhs)
        to_key <=> rhs.to_key
      end

      alias_method :eql?, :==
    end
  end
end
