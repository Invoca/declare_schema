# frozen_string_literal: true

require_relative 'base'

module DeclareSchema
  module SchemaChange
    class Base
      class << self
        def format_options(options)
          options.map do |k, v|
            value =
              if v.is_a?(Hash)
                "{ #{format_options(v).join(', ')} }"
              else
                v.inspect
              end
            if k.is_a?(Symbol)
              "#{k}: #{value}"
            else
              "#{k.inspect} => #{value}"
            end
          end
        end
      end

      def up
        up_command + spacing(up_command)
      end

      def down
        down_command + spacing(down_command)
      end

      private

      def spacing(command)
        if command["\n"]
          "\n\n"
        else
          "\n"
        end
      end
    end
  end
end
