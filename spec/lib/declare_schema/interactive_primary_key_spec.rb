# frozen_string_literal: true

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

    Rails::Generators.invoke('declare_schema:migration', %w[-n -m])
    expect(Foo.primary_key).to eq('foo_id')

    ### migrate from
    # rename from custom primary_key
    class Foo < ActiveRecord::Base
      fields do
      end
      self.primary_key = "id"
    end

    puts "\n\e[45m Please enter 'id' (no quotes) at the next prompt \e[0m"
    Rails::Generators.invoke('declare_schema:migration', %w[-n -m])
    expect(Foo.primary_key).to eq('id')

    nuke_model_class(Foo)

    ### migrate to

    # rename to custom primary_key
    class Foo < ActiveRecord::Base
      fields do
      end
      self.primary_key = "foo_id"
    end

    puts "\n\e[45m Please enter 'drop id' (no quotes) at the next prompt \e[0m"
    Rails::Generators.invoke('declare_schema:migration', %w[-n -m])
    expect(Foo.primary_key).to eq('foo_id')

    ### ensure it doesn't cause further migrations

    # check no further migrations
    up, down = Generators::DeclareSchema::Migration::Migrator.run
    expect(up).to eq("")
  end
end
