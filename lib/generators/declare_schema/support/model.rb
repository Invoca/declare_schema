# frozen_string_literal: true

require_relative './eval_template'

module DeclareSchema
  module Support
    module Model
      def self.included(base)
        base.class_eval do
          include EvalTemplate

          argument :attributes, :type => :array, :default => [], :banner => "field:type field:type"

          def self.banner
            "rails generate declare_schema:model #{self.arguments.map(&:usage).join(' ')} [options]"
          end

          class_option :timestamps, :type => :boolean

          def generate_model
            invoke "active_record:model", [name], {:migration => false}.merge(options)
          end

          def inject_declare_schema_code_into_model_file
            gsub_file(model_path, /  # attr_accessible :title, :body\n/m, "")
            inject_into_class model_path, class_name do
              eval_template('model_injection.rb.erb')
            end
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
            field_attributes.map(&:name) + bts.map {|bt| "#{bt}_id"} + bts + hms
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
