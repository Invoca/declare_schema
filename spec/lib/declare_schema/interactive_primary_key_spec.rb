# frozen_string_literal: true

RSpec.describe 'DeclareSchema Migration Generator interactive primary key' do
  let(:model_base_class) { Rails::VERSION::MAJOR > 4 ? 'ApplicationRecord' : 'ActiveRecord::Base' }

  before :all do
    load File.expand_path('prepare_testapp.rb', __dir__)
    ActiveRecord::Base.connection.execute("DROP TABLE foos") rescue nil
  end

  it "allows alternate primary keys" do
    instance_exec do
      class Foo < ActiveRecord::Base
        fields do
        end
        self.primary_key = "foo_id"
      end
    end

    puts "A"

    Rails::Generators.invoke('declare_schema:migration', %w[-n -m])
    expect(Foo.primary_key).to eq('foo_id')

    puts "B"
    ### migrate from
    # rename from custom primary_key
    instance_exec do
      class Foo < ActiveRecord::Base
        self.primary_key = "id"
      end
    end

    puts "C"
    puts "\n\e[45m Please enter 'id' (no quotes) at the next prompt \e[0m"
    Rails::Generators.invoke('declare_schema:migration', %w[-n -m])
    expect(Foo.primary_key).to eq('id')

    ### migrate to

    # rename to custom primary_key
    instance_exec do
      class Foo < ActiveRecord::Base
        self.primary_key = "foo_id"
      end
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
