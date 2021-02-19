# frozen_string_literal: true

require 'active_record'
require 'declare_schema/model'
require 'declare_schema/field_declaration_dsl'

module DeclareSchema
  module FieldsDsl
    deprecate :fields, deprecator: ActiveSupport::Deprecation.new('1.0', 'DeclareSchema')

    def fields(table_options = {}, &block)
      declare_schema(table_options, &block)
    end

    def declare_schema(table_options = {}, &block)
      # Any model that calls 'fields' gets DeclareSchema::Model behavior
      DeclareSchema::Model.mix_in(self)

      # @include_in_migration = false #||= options.fetch(:include_in_migration, true); options.delete(:include_in_migration)
      @include_in_migration = true
      @table_options        = table_options

      if block
        dsl = DeclareSchema::FieldDeclarationDsl.new(self, null: false)
        if block.arity == 1
          yield dsl
        else
          dsl.instance_eval(&block)
        end
      end
    end
  end
end

ActiveRecord::Base.singleton_class.prepend DeclareSchema::FieldsDsl
