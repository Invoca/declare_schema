# frozen_string_literal: true

module DeclareSchema
  module SchemaChange
    autoload :Base, 'declare_schema/schema_change/base'
    autoload :ColumnAdd, 'declare_schema/schema_change/column_add'
    autoload :ColumnChange, 'declare_schema/schema_change/column_change'
    autoload :ColumnRename, 'declare_schema/schema_change/column_rename'
    autoload :ForeignKeyAdd, 'declare_schema/schema_change/foreign_key_add'
    autoload :ForeignKeyRemove, 'declare_schema/schema_change/foreign_key_remove'
    autoload :IndexAdd, 'declare_schema/schema_change/index_add'
    autoload :IndexRemove, 'declare_schema/schema_change/index_remove'
    autoload :PrimaryKeyChange, 'declare_schema/schema_change/primary_key_change'
    autoload :TableAdd, 'declare_schema/schema_change/table_add'
    autoload :TableChange, 'declare_schema/schema_change/table_change'
    autoload :TableRemove, 'declare_schema/schema_change/table_remove'
    autoload :TableRename, 'declare_schema/schema_change/table_rename'
  end
end

