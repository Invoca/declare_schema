# frozen_string_literal: true

require 'active_record'
require 'declare_schema/dsl'
require 'declare_schema/model'
require 'declare_schema/field_declaration_dsl'

module DeclareSchema
  module Macros
    attr_reader :_table_options

    def declare_schema(default_schema: true, **table_options, &block)
      # Any model that calls 'fields' gets DeclareSchema::Model behavior
      DeclareSchema::Model.mix_in(self)

      # @include_in_migration = false #||= options.fetch(:include_in_migration, true); options.delete(:include_in_migration)
      @include_in_migration = true # TODO: Add back or delete the include_in_migration feature
      @_table_options        = table_options

      if block
        dsl = DeclareSchema::Dsl.new(self, null: false)
        dsl.instance_eval(&block)
        if default_schema && DeclareSchema.default_schema
          dsl.instance_exec(&DeclareSchema.default_schema)
        end
      end
    end
  end
end

ActiveRecord::Base.singleton_class.prepend DeclareSchema::Macros
