# frozen_string_literal: true

require_relative 'base'

module DeclareSchema
  module SchemaChange
    class Base
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
