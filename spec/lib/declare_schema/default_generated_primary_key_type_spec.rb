# frozen_string_literal: true

require 'generators/declare_schema/support/thor_shell'

# Verifies that when the migrator has to add a declared primary key column
# that has no corresponding FieldSpec (because it was appended to `to_add`
# at lib/generators/declare_schema/migration/migrator.rb:366), the column
# type is derived from `DeclareSchema.default_generated_primary_key_type`
# rather than a hardcoded `:integer`. This matters for apps that override
# `config.generators.primary_key_type`.
RSpec.describe 'DeclareSchema.default_generated_primary_key_type integration with Migrator' do
  include_context 'prepare test app'

  before do
    if current_adapter == 'mysql2'
      ActiveRecord::Base.connection.execute("CREATE TABLE foos (id int PRIMARY KEY, name varchar(250))")
    else
      ActiveRecord::Base.connection.execute("CREATE TABLE foos (id integer PRIMARY KEY AUTOINCREMENT NOT NULL, name varchar(250))")
    end
    ActiveRecord::Base.connection.schema_cache.clear!

    allow_any_instance_of(DeclareSchema::Support::ThorShell)
      .to receive(:ask).with(/one of the rename choices or press enter to keep/) { 'drop id' }
  end

  it 'derives the new PK column type from DeclareSchema.default_generated_primary_key_type rather than a hardcoded :integer' do
    allow(::DeclareSchema).to receive(:default_generated_primary_key_type).and_return(:string)

    class Foo < ActiveRecord::Base # rubocop:disable Lint/ConstantDefinitionInBlock
      declare_schema do
        string :name, limit: 250
      end
      self.primary_key = "foo_id"
    end

    up, _down = Generators::DeclareSchema::Migration::Migrator.run

    expect(up).to include("add_column :foos, :foo_id, :string")
    expect(up).not_to include("add_column :foos, :foo_id, :integer")
  end

  it 'falls through to the configured Rails default (:bigint) when the helper is not stubbed' do
    class Foo < ActiveRecord::Base # rubocop:disable Lint/ConstantDefinitionInBlock
      declare_schema do
        string :name, limit: 250
      end
      self.primary_key = "foo_id"
    end

    up, _down = Generators::DeclareSchema::Migration::Migrator.run

    expect(up).to include("add_column :foos, :foo_id, #{::DeclareSchema.default_generated_primary_key_type.inspect}")
  end
end
