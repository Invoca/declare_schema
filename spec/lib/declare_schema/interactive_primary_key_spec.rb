# frozen_string_literal: true

RSpec.describe 'DeclareSchema Migration Generator interactive primary key' do
  before do
    load File.expand_path('prepare_testapp.rb', __dir__)

    # Currently tests are run against sqlite which only has support for binary, nocase, and rtrim collation
    Generators::DeclareSchema::Migration::Migrator.default_collation = :binary
  end

  after { Generators::DeclareSchema::Migration::Migrator.default_collation = Generators::DeclareSchema::Migration::Migrator::DEFAULT_COLLATION }

  it "allows alternate primary keys" do
    class Foo < ActiveRecord::Base
      fields do
      end
      self.primary_key = "foo_id"
    end

    generate_migrations '-n', '-m'
    expect(Foo.primary_key).to eq('foo_id')

    ### migrate from
    # rename from custom primary_key
    class Foo < ActiveRecord::Base
      fields do
      end
      self.primary_key = "id"
    end

    puts "\n\e[45m Please enter 'id' (no quotes) at the next prompt \e[0m"
    generate_migrations '-n', '-m'
    expect(Foo.primary_key).to eq('id')

    nuke_model_class(Foo)

    ### migrate to

    if Rails::VERSION::MAJOR >= 5
      # rename to custom primary_key
      class Foo < ActiveRecord::Base
        fields do
        end
        self.primary_key = "foo_id"
      end

      puts "\n\e[45m Please enter 'drop id' (no quotes) at the next prompt \e[0m"
      generate_migrations '-n', '-m'
      expect(Foo.primary_key).to eq('foo_id')

      ### ensure it doesn't cause further migrations

      # check no further migrations
      up = Generators::DeclareSchema::Migration::Migrator.run.first
      expect(up).to eq("")
    end
  end
end
