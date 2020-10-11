# frozen_string_literal: true

require_relative './eval_template'

module DeclareSchema
  module Support
    class IndentedBuffer
      def initialize(indent: 0)
        @string = +""
        @indent = indent
        @column = 0
        @indent_amount = 2
      end

      def to_string
        @string
      end

      def indent!
        @indent += @indent_amount
        yield
        @indent -= @indent_amount
      end

      def newline!
        @column = 0
        @string << "\n"
      end

      def <<(str)
        if (difference = @indent - @column) > 0
          @string << ' ' * difference
        end
        @column += difference
        @string << str
        newline!
      end
    end

    module Model
      class << self
        def included(base)
          base.class_eval do
            include EvalTemplate

            argument :attributes, type: :array, default: [], banner: "field:type field:type"

            class << self
              def banner
                "rails generate declare_schema:model #{arguments.map(&:usage).join(' ')} [options]"
              end
            end

            class_option :timestamps, type: :boolean

            def generate_model
              invoke "active_record:model", [name], { migration: false }.merge(options)
            end

            def inject_declare_schema_code_into_model_file
              gsub_file(model_path, /  # attr_accessible :title, :body\n/m, "")
              inject_into_class(model_path, class_name) do
                declare_model_fields_and_associations
              end
            end

            private

            def declare_model_fields_and_associations
              buffer = ::DeclareSchema::Support::IndentedBuffer.new(indent: 2)
              buffer.newline!
              buffer << 'fields do'
              buffer.indent! do
                field_attributes.each do |attribute|
                  decl = "%-#{max_attribute_length}s" % attribute.name + ' ' +
                    attribute.type.to_sym.inspect +
                    case attribute.type.to_s
                    when 'string'
                      ', limit: 255'
                    else
                      ''
                    end
                  buffer << decl
                end
                if options[:timestamps]
                  buffer.newline!
                  buffer << 'timestamps'
                end
              end
              buffer << 'end'

              if bts.any?
                buffer.newline!
                bts.each do |bt|
                  buffer << "belongs_to #{bt.to_sym.inspect}"
                end
              end
              if hms.any?
                buffer.newline
                hms.each do |hm|
                  buffer << "has_many #{hm.to_sym.inspect}, dependent: :destroy"
                end
              end
              buffer.newline!

              buffer.to_string
            end

            protected

            def model_path
              @model_path ||= File.join("app", "models", "#{file_path}.rb")
            end

            def max_attribute_length
              attributes.map { |attribute| attribute.name.length }.max
            end

            def field_attributes
              attributes.reject { |a| a.name == "bt" || a.name == "hm" }
            end

            def accessible_attributes
              field_attributes.map(&:name) + bts.map { |bt| "#{bt}_id" } + bts + hms
            end

            def hms
              attributes.select { |a| a.name == "hm" }.map(&:type)
            end

            def bts
              attributes.select { |a| a.name == "bt" }.map(&:type)
            end
          end
        end
      end
    end
  end
end
