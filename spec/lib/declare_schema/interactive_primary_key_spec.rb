# frozen_string_literal: true

require 'rails'
begin
  require 'mysql2'
rescue LoadError
end

RSpec.describe 'DeclareSchema Migration Generator interactive primary key' do
  before do
    load File.expand_path('prepare_testapp.rb', __dir__)
  end

  it "allows alternate primary keys" do
    class Foo < ActiveRecord::Base
      fields do
      end
      self.primary_key = "foo_id"
    end

    generate_migrations '-n', '-m'
    expect(Foo._defined_primary_key).to eq('foo_id')

    ### migrate from
    # rename from custom primary_key
    class Foo < ActiveRecord::Base
      fields do
      end
      self.primary_key = "id"
    end

    puts "\n\e[45m Please enter 'id' (no quotes) at the next prompt \e[0m"
    generate_migrations '-n', '-m'
    expect(Foo._defined_primary_key).to eq('id')

    nuke_model_class(Foo)

    # The ActiveRecord sqlite3 driver has a bug where rename_column recreates the entire table, but forgets to set the primary key:
    #
    # [7] pry(#<RSpec::ExampleGroups::DeclareSchemaMigrationGeneratorInteractivePrimaryKey>)> u = 'rename_column :foos, :foo_id, :id'
    # => "rename_column :foos, :foo_id, :id"
    # [8] pry(#<RSpec::ExampleGroups::DeclareSchemaMigrationGeneratorInteractivePrimaryKey>)> ActiveRecord::Migration.class_eval(u)
    # (0.0ms)  begin transaction
    #  (pry):17
    # (0.2ms)  CREATE TEMPORARY TABLE "afoos" ("id" integer NOT NULL)
    #  (pry):17
    # (0.1ms)  INSERT INTO "afoos" ("id")
    #
    #  (pry):17
    # (0.4ms)  DROP TABLE "foos"
    #  (pry):17
    # (0.1ms)  CREATE TABLE "foos" ("id" integer NOT NULL)
    #  (pry):17
    # (0.1ms)  INSERT INTO "foos" ("id")
    #
    #  (pry):17
    # (0.1ms)  DROP TABLE "afoos"
    #  (pry):17
    # (0.9ms)  commit transaction
    if defined?(SQLite3)
      ActiveRecord::Base.connection.execute("drop table foos")
      ActiveRecord::Base.connection.execute("CREATE TABLE foos (id integer PRIMARY KEY AUTOINCREMENT NOT NULL)")
    end

    ### migrate to

    if Rails::VERSION::MAJOR >= 5 && !defined?(Mysql2) # TODO TECH-4814 Put this test back for Mysql2
      # replace custom primary_key
      class Foo < ActiveRecord::Base
        fields do
        end
        self.primary_key = "foo_id"
      end

      puts "\n\e[45m Please enter 'drop id' (no quotes) at the next prompt \e[0m"
      generate_migrations '-n', '-m'
      expect(Foo._defined_primary_key).to eq('foo_id')
    end
  end
end
