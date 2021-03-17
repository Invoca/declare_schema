# frozen_string_literal: true

require_relative 'base'

module DeclareSchema
  module SchemaChange
    class TableAdd < Base
      def initialize(table_name, fields, create_table_options, sql_options: nil)
        @table_name = table_name
        fields.all? do |type, name, options|
          type.is_a?(Symbol) && name.is_a?(Symbol) && options.is_a?(Hash)
        end or raise ArgumentError, "fields must be Array(Array(Symbol, Symbol, Hash)); got #{fields.inspect}"
        @fields = fields
        @create_table_options = create_table_options
        @create_table_options = @create_table_options.merge(options: sql_options) if sql_options.present?
      end

      def up_command
        longest_field_type_length = @fields.map { |type, _name, _option| type.to_s.length }.max

        <<~EOS.strip
          create_table #{[@table_name.to_sym.inspect, *self.class.format_options(@create_table_options)].join(', ')} do |t|
          #{@fields.map do |type, name, options|
              padded_type = format("%-*s", longest_field_type_length, type)
              args = [name.inspect, *self.class.format_options(options)].join(', ')
              "  t.#{padded_type} #{args}"
            end.join("\n")}
          end
        EOS
      end

      def down_command
        "drop_table #{@table_name.to_sym.inspect}"
      end
    end
  end
end
