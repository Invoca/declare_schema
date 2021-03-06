# frozen_string_literal: true

require_relative 'base'

module DeclareSchema
  module SchemaChange
    class Base
      class << self
        def format_options(options)
          options.map do |k, v|
            if k.is_a?(Symbol)
              "#{k}: #{v.inspect}"
            else
              "#{k.inspect} => #{v.inspect}"
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
