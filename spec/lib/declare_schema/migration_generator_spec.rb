# frozen_string_literal: true

require 'rails'

RSpec.describe 'DeclareSchema Migration Generator' do
  before do
    load File.expand_path('prepare_testapp.rb', __dir__)
  end

  # DeclareSchema - Migration Generator
  it 'generates migrations' do
    ## The migration generator -- introduction

    up_down = Generators::DeclareSchema::Migration::Migrator.run
    expect(up_down).to eq(["", ""])

    class Advert < ActiveRecord::Base
    end

    up_down = Generators::DeclareSchema::Migration::Migrator.run
    expect(up_down).to eq(["", ""])

    Generators::DeclareSchema::Migration::Migrator.ignore_tables = ["green_fishes"]

    Advert.connection.schema_cache.clear!
    Advert.reset_column_information

    class Advert < ActiveRecord::Base
      fields do
        name :string, limit: 255, null: true
      end
    end
    up, down = Generators::DeclareSchema::Migration::Migrator.run
    expect(up).to eq(<<~EOS.strip)
      create_table :adverts, id: :bigint do |t|
        t.string :name, limit: 255
      end
    EOS
    expect(down).to eq("drop_table :adverts")

    ActiveRecord::Migration.class_eval(up)
    expect(Advert.columns.map(&:name)).to eq(["id", "name"])

    class Advert < ActiveRecord::Base
      fields do
        name :string, limit: 255, null: true
        body :text, null: true
        published_at :datetime, null: true
      end
    end
    up, down = migrate
    expect(up).to eq(<<~EOS.strip)
      add_column :adverts, :body, :text
      add_column :adverts, :published_at, :datetime

      add_index :adverts, [:id], unique: true, name: 'PRIMARY_KEY'
    EOS
    # TODO: ^ TECH-4975 add_index should not be there

    expect(down).to eq(<<~EOS.strip)
      remove_column :adverts, :body
      remove_column :adverts, :published_at
    EOS

    Advert.field_specs.clear # not normally needed
    class Advert < ActiveRecord::Base
      fields do
        name :string, limit: 255, null: true
        body :text, null: true
      end
    end

    up, down = migrate
    expect(up).to eq("remove_column :adverts, :published_at")
    expect(down).to eq("add_column :adverts, :published_at, :datetime")

    nuke_model_class(Advert)
    class Advert < ActiveRecord::Base
      fields do
        title :string, limit: 255, null: true
        body :text, null: true
      end
    end

    up, down = Generators::DeclareSchema::Migration::Migrator.run
    expect(up).to eq(<<~EOS.strip)
      add_column :adverts, :title, :string, limit: 255
      remove_column :adverts, :name
    EOS

    expect(down).to eq(<<~EOS.strip)
      remove_column :adverts, :title
      add_column :adverts, :name, :string, limit: 255
    EOS

    up, down = Generators::DeclareSchema::Migration::Migrator.run(adverts: { name: :title })
    expect(up).to eq("rename_column :adverts, :name, :title")
    expect(down).to eq("rename_column :adverts, :title, :name")

    migrate

    class Advert < ActiveRecord::Base
      fields do
        title :text, null: true
        body :text, null: true
      end
    end

    up_down = Generators::DeclareSchema::Migration::Migrator.run
    expect(up_down).to eq(["change_column :adverts, :title, :text",
                           "change_column :adverts, :title, :string, limit: 255"])

    class Advert < ActiveRecord::Base
      fields do
        title :string, default: "Untitled", limit: 255, null: true
        body :text, null: true
      end
    end

    up, down = migrate
    expect(up.split(',').slice(0,3).join(',')).to eq('change_column :adverts, :title, :string')
    expect(up.split(',').slice(3,2).sort.join(',')).to eq(" default: \"Untitled\", limit: 255")
    expect(down).to eq("change_column :adverts, :title, :string, limit: 255")


    ### Limits

    class Advert < ActiveRecord::Base
      fields do
        price :integer, null: true, limit: 2
      end
    end

    up = Generators::DeclareSchema::Migration::Migrator.run.first
    expect(up).to eq("add_column :adverts, :price, :integer, limit: 2")

    # Now run the migration, then change the limit:

    ActiveRecord::Migration.class_eval(up)
    class Advert < ActiveRecord::Base
      fields do
        price :integer, null: true, limit: 3
      end
    end

    up, down = Generators::DeclareSchema::Migration::Migrator.run
    expect(up).to eq("change_column :adverts, :price, :integer, limit: 3")
    expect(down).to eq("change_column :adverts, :price, :integer, limit: 2")

    # Note that limit on a decimal column is ignored (use :scale and :precision)

    ActiveRecord::Migration.class_eval("remove_column :adverts, :price")
    class Advert < ActiveRecord::Base
      fields do
        price :decimal, null: true, limit: 4
      end
    end

    up = Generators::DeclareSchema::Migration::Migrator.run.first
    expect(up).to eq("add_column :adverts, :price, :decimal")

    # Limits are generally not needed for `text` fields, because by default, `text` fields will use the maximum size
    # allowed for that database type (0xffffffff for LONGTEXT in MySQL unlimited in Postgres, 1 billion in Sqlite).
    # If a `limit` is given, it will only be used in MySQL, to choose the smallest TEXT field that will accommodate
    # that limit (0xff for TINYTEXT, 0xffff for TEXT, 0xffffff for MEDIUMTEXT, 0xffffffff for LONGTEXT).

    expect(::DeclareSchema::Model::FieldSpec.mysql_text_limits?).to be_falsey
    class Advert < ActiveRecord::Base
      fields do
        notes :text
        description :text, limit: 30000
      end
    end

    up = Generators::DeclareSchema::Migration::Migrator.run.first
    expect(up).to eq(<<~EOS.strip)
      add_column :adverts, :price, :decimal
      add_column :adverts, :notes, :text, null: false
      add_column :adverts, :description, :text, null: false
    EOS

    # (There is no limit on `add_column ... :description` above since these tests are run against SQLite.)

    Advert.field_specs.delete :price
    Advert.field_specs.delete :notes
    Advert.field_specs.delete :description

    # In MySQL, limits are applied, rounded up:

    ::DeclareSchema::Model::FieldSpec::instance_variable_set(:@mysql_text_limits, true)
    expect(::DeclareSchema::Model::FieldSpec.mysql_text_limits?).to be_truthy
    class Advert < ActiveRecord::Base
      fields do
        notes :text
        description :text, limit: 200
      end
    end

    up = Generators::DeclareSchema::Migration::Migrator.run.first
    expect(up).to eq(<<~EOS.strip)
      add_column :adverts, :notes, :text, null: false, limit: 4294967295
      add_column :adverts, :description, :text, null: false, limit: 255
    EOS

    Advert.field_specs.delete :notes

    # Limits that are too high for MySQL will raise an exception.

    ::DeclareSchema::Model::FieldSpec::instance_variable_set(:@mysql_text_limits, true)
    expect(::DeclareSchema::Model::FieldSpec.mysql_text_limits?).to be_truthy
    expect do
      class Advert < ActiveRecord::Base
        fields do
          notes :text
          description :text, limit: 0x1_0000_0000
        end
      end
    end.to raise_exception(ArgumentError, "limit of 4294967296 is too large for MySQL")

    Advert.field_specs.delete :notes

    # And in MySQL, unstated text limits are treated as the maximum (LONGTEXT) limit.

    # To start, we'll set the database schema for `description` to match the above limit of 255.

    expect(::DeclareSchema::Model::FieldSpec.mysql_text_limits?).to be_truthy
    Advert.connection.execute "ALTER TABLE adverts ADD COLUMN description TINYTEXT"
    Advert.connection.schema_cache.clear!
    Advert.reset_column_information
    expect(Advert.connection.tables - Generators::DeclareSchema::Migration::Migrator.always_ignore_tables).
      to eq(["adverts"])
    expect(Advert.columns.map(&:name)).to eq(["id", "body", "title", "description"])

    # Now migrate to an unstated text limit:

    class Advert < ActiveRecord::Base
      fields do
        description :text
      end
    end

    up, down = Generators::DeclareSchema::Migration::Migrator.run
    expect(up).to eq("change_column :adverts, :description, :text, limit: 4294967295, null: false")
    expect(down).to eq("change_column :adverts, :description, :text")

    # TODO TECH-4814: The above test should have this output:
    # TODO => "change_column :adverts, :description, :text, limit: 255

    # And migrate to a stated text limit that is the same as the unstated one:

    class Advert < ActiveRecord::Base
      fields do
        description :text, limit: 0xffffffff
      end
    end

    up, down = Generators::DeclareSchema::Migration::Migrator.run
    expect(up).to eq("change_column :adverts, :description, :text, limit: 4294967295, null: false")
    expect(down).to eq("change_column :adverts, :description, :text")
    ::DeclareSchema::Model::FieldSpec::instance_variable_set(:@mysql_text_limits, false)

    Advert.field_specs.clear
    Advert.connection.schema_cache.clear!
    Advert.reset_column_information
    class Advert < ActiveRecord::Base
      fields do
        name :string, limit: 255, null: true
      end
    end

    up = Generators::DeclareSchema::Migration::Migrator.run.first
    ActiveRecord::Migration.class_eval up
    Advert.connection.schema_cache.clear!
    Advert.reset_column_information

    ### Foreign Keys

    # DeclareSchema extends the `belongs_to` macro so that it also declares the
    # foreign-key field.  It also generates an index on the field.

    class Category < ActiveRecord::Base; end
    class Advert < ActiveRecord::Base
      fields do
        name :string, limit: 255, null: true
      end
      belongs_to :category
    end

    up, down = Generators::DeclareSchema::Migration::Migrator.run
    expect(up.gsub(/\n+/, "\n")).to eq(<<~EOS.strip)
      add_column :adverts, :category_id, :integer, limit: 8, null: false
      add_index :adverts, [:category_id], name: 'on_category_id'
    EOS
    expect(down.sub(/\n+/, "\n")).to eq(<<~EOS.strip)
      remove_column :adverts, :category_id
      remove_index :adverts, name: :on_category_id rescue ActiveRecord::StatementInvalid
    EOS

    Advert.field_specs.delete(:category_id)
    Advert.index_specs.delete_if {|spec| spec.fields==["category_id"]}

    # If you specify a custom foreign key, the migration generator observes that:

    class Category < ActiveRecord::Base; end
    class Advert < ActiveRecord::Base
      fields { }
      belongs_to :category, foreign_key: "c_id", class_name: 'Category'
    end
    up = Generators::DeclareSchema::Migration::Migrator.run.first
    expect(up.gsub(/\n+/, "\n")).to eq(<<~EOS.strip)
      add_column :adverts, :c_id, :integer, limit: 8, null: false
      add_index :adverts, [:c_id], name: 'on_c_id'
    EOS

    Advert.field_specs.delete(:c_id)
    Advert.index_specs.delete_if { |spec| spec.fields == ["c_id"] }

    # You can avoid generating the index by specifying `index: false`

    class Category < ActiveRecord::Base; end
    class Advert < ActiveRecord::Base
      fields { }
      belongs_to :category, index: false
    end
    up = Generators::DeclareSchema::Migration::Migrator.run.first
    expect(up.gsub(/\n+/, "\n")).to eq("add_column :adverts, :category_id, :integer, limit: 8, null: false")

    Advert.field_specs.delete(:category_id)
    Advert.index_specs.delete_if { |spec| spec.fields == ["category_id"] }

    # You can specify the index name with :index

    class Category < ActiveRecord::Base; end
    class Advert < ActiveRecord::Base
      fields { }
      belongs_to :category, index: 'my_index'
    end
    up = Generators::DeclareSchema::Migration::Migrator.run.first
    expect(up.gsub(/\n+/, "\n")).to eq(<<~EOS.strip)
      add_column :adverts, :category_id, :integer, limit: 8, null: false
      add_index :adverts, [:category_id], name: 'my_index'
    EOS

    Advert.field_specs.delete(:category_id)
    Advert.index_specs.delete_if { |spec| spec.fields == ["category_id"] }

    ### Timestamps and Optimimistic Locking

    # `updated_at` and `created_at` can be declared with the shorthand `timestamps`.
    # Similarly, `lock_version` can be declared with the "shorthand" `optimimistic_lock`.

    class Advert < ActiveRecord::Base
      fields do
        timestamps
        optimistic_lock
      end
    end
    up, down = Generators::DeclareSchema::Migration::Migrator.run
    expect(up.gsub(/\n+/, "\n")).to eq(<<~EOS.strip)
      add_column :adverts, :created_at, :datetime
      add_column :adverts, :updated_at, :datetime
      add_column :adverts, :lock_version, :integer, null: false, default: 1
    EOS
    expect(down.gsub(/\n+/, "\n")).to eq(<<~EOS.strip)
      remove_column :adverts, :created_at
      remove_column :adverts, :updated_at
      remove_column :adverts, :lock_version
    EOS

    Advert.field_specs.delete(:updated_at)
    Advert.field_specs.delete(:created_at)
    Advert.field_specs.delete(:lock_version)

    ### Indices

    # You can add an index to a field definition

    class Advert < ActiveRecord::Base
      fields do
        title :string, index: true, limit: 255, null: true
      end
    end
    up = Generators::DeclareSchema::Migration::Migrator.run.first
    expect(up.gsub(/\n+/, "\n")).to eq(<<~EOS.strip)
      add_column :adverts, :title, :string, limit: 255
      add_index :adverts, [:title], name: 'on_title'
    EOS

    Advert.index_specs.delete_if { |spec| spec.fields==["title"] }

    # You can ask for a unique index

    class Advert < ActiveRecord::Base
      fields do
        title :string, index: true, unique: true, null: true, limit: 255
      end
    end
    up = Generators::DeclareSchema::Migration::Migrator.run.first
    expect(up.gsub(/\n+/, "\n")).to eq(<<~EOS.strip)
      add_column :adverts, :title, :string, limit: 255
      add_index :adverts, [:title], unique: true, name: 'on_title'
    EOS

    Advert.index_specs.delete_if { |spec| spec.fields == ["title"] }

    # You can specify the name for the index

    class Advert < ActiveRecord::Base
      fields do
        title :string, index: 'my_index', limit: 255, null: true
      end
    end
    up = Generators::DeclareSchema::Migration::Migrator.run.first
    expect(up.gsub(/\n+/, "\n")).to eq(<<~EOS.strip)
      add_column :adverts, :title, :string, limit: 255
      add_index :adverts, [:title], name: 'my_index'
    EOS

    Advert.index_specs.delete_if { |spec| spec.fields==["title"] }

    # You can ask for an index outside of the fields block

    class Advert < ActiveRecord::Base
      index :title
    end
    up = Generators::DeclareSchema::Migration::Migrator.run.first
    expect(up.gsub(/\n+/, "\n")).to eq(<<~EOS.strip)
      add_column :adverts, :title, :string, limit: 255
      add_index :adverts, [:title], name: 'on_title'
    EOS

    Advert.index_specs.delete_if { |spec| spec.fields == ["title"] }

    # The available options for the index function are `:unique` and `:name`

    class Advert < ActiveRecord::Base
      index :title, unique: true, name: 'my_index'
    end
    up = Generators::DeclareSchema::Migration::Migrator.run.first
    expect(up.gsub(/\n+/, "\n")).to eq(<<~EOS.strip)
      add_column :adverts, :title, :string, limit: 255
      add_index :adverts, [:title], unique: true, name: 'my_index'
    EOS

    Advert.index_specs.delete_if { |spec| spec.fields == ["title"] }

    # You can create an index on more than one field

    class Advert < ActiveRecord::Base
      index [:title, :category_id]
    end
    up = Generators::DeclareSchema::Migration::Migrator.run.first
    expect(up.gsub(/\n+/, "\n")).to eq(<<~EOS.strip)
      add_column :adverts, :title, :string, limit: 255
      add_index :adverts, [:title, :category_id], name: 'on_title_and_category_id'
    EOS

    Advert.index_specs.delete_if { |spec| spec.fields==["title", "category_id"] }

    # Finally, you can specify that the migration generator should completely ignore an
    # index by passing its name to ignore_index in the model.
    # This is helpful for preserving indices that can't be automatically generated, such as prefix indices in MySQL.

    ### Rename a table

    # The migration generator respects the `set_table_name` declaration, although as before, we need to explicitly tell the generator that we want a rename rather than a create and a drop.

    class Advert < ActiveRecord::Base
      self.table_name = "ads"
      fields do
        title :string, limit: 255, null: true
        body :text, null: true
      end
    end

    Advert.connection.schema_cache.clear!
    Advert.reset_column_information

    up, down = Generators::DeclareSchema::Migration::Migrator.run("adverts" => "ads")
    expect(up.gsub(/\n+/, "\n")).to eq(<<~EOS.strip)
      rename_table :adverts, :ads
      add_column :ads, :title, :string, limit: 255
      add_column :ads, :body, :text
      add_index :ads, [:id], unique: true, name: 'PRIMARY_KEY'
    EOS
    expect(down.gsub(/\n+/, "\n")).to eq(<<~EOS.strip)
      remove_column :ads, :title
      remove_column :ads, :body
      rename_table :ads, :adverts
      add_index :adverts, [:id], unique: true, name: 'PRIMARY_KEY'
    EOS

    # Set the table name back to what it should be and confirm we're in sync:

    Advert.field_specs.delete(:title)
    Advert.field_specs.delete(:body)
    class Advert < ActiveRecord::Base
      self.table_name = "adverts"
    end

    expect(Generators::DeclareSchema::Migration::Migrator.run).to eq(["", ""])

    ### Rename a table

    # As with renaming columns, we have to tell the migration generator about the rename. Here we create a new class 'Advertisement', and tell ActiveRecord to forget about the Advert class. This requires code that shouldn't be shown to impressionable children.

    nuke_model_class(Advert)

    class Advertisement < ActiveRecord::Base
      fields do
        title :string, limit: 255, null: true
        body :text, null: true
      end
    end
    up, down = Generators::DeclareSchema::Migration::Migrator.run("adverts" => "advertisements")
    expect(up.gsub(/\n+/, "\n")).to eq(<<~EOS.strip)
      rename_table :adverts, :advertisements
      add_column :advertisements, :title, :string, limit: 255
      add_column :advertisements, :body, :text
      remove_column :advertisements, :name
      add_index :advertisements, [:id], unique: true, name: 'PRIMARY_KEY'
    EOS
    expect(down.gsub(/\n+/, "\n")).to eq(<<~EOS.strip)
      remove_column :advertisements, :title
      remove_column :advertisements, :body
      add_column :adverts, :name, :string, limit: 255
      rename_table :advertisements, :adverts
      add_index :adverts, [:id], unique: true, name: 'PRIMARY_KEY'
    EOS

    ### Drop a table

    nuke_model_class(Advertisement)

    # If you delete a model, the migration generator will create a `drop_table` migration.

    # Dropping tables is where the automatic down-migration really comes in handy:

    up, down = Generators::DeclareSchema::Migration::Migrator.run
    expect(up).to eq("drop_table :adverts")
    expect(down.gsub(/,.*/m, '')).to eq("create_table \"adverts\"")

    ## STI

    ### Adding an STI subclass

    # Adding a subclass or two should introduce the 'type' column and no other changes

    class Advert < ActiveRecord::Base
      fields do
        body :text, null: true
        title :string, default: "Untitled", limit: 255, null: true
      end
    end
    up = Generators::DeclareSchema::Migration::Migrator.run.first
    ActiveRecord::Migration.class_eval(up)

    class FancyAdvert < Advert
    end
    class SuperFancyAdvert < FancyAdvert
    end
    up, down = Generators::DeclareSchema::Migration::Migrator.run
    expect(up.gsub(/\n+/, "\n")).to eq(<<~EOS.strip)
      add_column :adverts, :type, :string, limit: 255
      add_index :adverts, [:type], name: 'on_type'
    EOS
    expect(down.gsub(/\n+/, "\n")).to eq(<<~EOS.strip)
      remove_column :adverts, :type
      remove_index :adverts, name: :on_type rescue ActiveRecord::StatementInvalid
    EOS

    Advert.field_specs.delete(:type)
    nuke_model_class(SuperFancyAdvert)
    nuke_model_class(FancyAdvert)
    Advert.index_specs.delete_if { |spec| spec.fields==["type"] }

    ## Coping with multiple changes

    # The migration generator is designed to create complete migrations even if many changes to the models have taken place.

    # First let's confirm we're in a known state. One model, 'Advert', with a string 'title' and text 'body':

    ActiveRecord::Migration.class_eval up.gsub(/.*type.*/, '')
    Advert.connection.schema_cache.clear!
    Advert.reset_column_information

    expect(Advert.connection.tables - Generators::DeclareSchema::Migration::Migrator.always_ignore_tables).
      to eq(["adverts"])
    expect(Advert.columns.map(&:name).sort).to eq(["body", "id", "title"])
    expect(Generators::DeclareSchema::Migration::Migrator.run).to eq(["", ""])


    ### Rename a column and change the default

    Advert.field_specs.clear

    class Advert < ActiveRecord::Base
      fields do
        name :string, default: "No Name", limit: 255, null: true
        body :text, null: true
      end
    end
    up, down = Generators::DeclareSchema::Migration::Migrator.run(adverts: { title: :name })
    expect(up).to eq(<<~EOS.strip)
      rename_column :adverts, :title, :name
      change_column :adverts, :name, :string, limit: 255, default: \"No Name\"
    EOS

    expect(down).to eq(<<~EOS.strip)
      rename_column :adverts, :name, :title
      change_column :adverts, :title, :string, limit: 255, default: \"Untitled\"
    EOS

    ### Rename a table and add a column

    nuke_model_class(Advert)
    class Ad < ActiveRecord::Base
      fields do
        title      :string, default: "Untitled", limit: 255
        body       :text, null: true
        created_at :datetime
      end
    end
    up = Generators::DeclareSchema::Migration::Migrator.run(adverts: :ads).first
    expect(up.gsub(/\n+/, "\n")).to eq(<<~EOS.strip)
      rename_table :adverts, :ads
      add_column :ads, :created_at, :datetime, null: false
      change_column :ads, :title, :string, limit: 255, null: false, default: \"Untitled\"
      add_index :ads, [:id], unique: true, name: 'PRIMARY_KEY'
    EOS

    class Advert < ActiveRecord::Base
      fields do
        body :text, null: true
        title :string, default: "Untitled", limit: 255, null: true
      end
    end

    ## Legacy Keys

    # DeclareSchema has some support for legacy keys.

    nuke_model_class(Ad)

    class Advert < ActiveRecord::Base
      fields do
        body :text, null: true
      end
      self.primary_key = "advert_id"
    end
    up, _down = Generators::DeclareSchema::Migration::Migrator.run(adverts: { id: :advert_id })
    expect(up.gsub(/\n+/, "\n")).to eq(<<~EOS.strip)
      rename_column :adverts, :id, :advert_id
      add_index :adverts, [:advert_id], unique: true, name: 'PRIMARY_KEY'
    EOS

    nuke_model_class(Advert)
    ActiveRecord::Base.connection.execute("drop table `adverts`;")

    ## DSL

    # The DSL allows lambdas and constants

    class User < ActiveRecord::Base
      fields do
        company :string, limit: 255, ruby_default: -> { "BigCorp" }
      end
    end
    expect(User.field_specs.keys).to eq(['company'])
    expect(User.field_specs['company'].options[:ruby_default]&.call).to eq("BigCorp")

    ## validates

    # DeclareSchema can accept a validates hash in the field options.

    class Ad < ActiveRecord::Base
      class << self
        def validates(field_name, options)
        end
      end
    end
    expect(Ad).to receive(:validates).with(:company, presence: true, uniqueness: { case_sensitive: false })
    class Ad < ActiveRecord::Base
      fields do
        company :string, limit: 255, index: true, unique: true, validates: { presence: true, uniqueness: { case_sensitive: false } }
      end
      self.primary_key = "advert_id"
    end
    up, _down = Generators::DeclareSchema::Migration::Migrator.run
    ActiveRecord::Migration.class_eval(up)
    expect(Ad.field_specs['company'].options[:validates].inspect).to eq("{:presence=>true, :uniqueness=>{:case_sensitive=>false}}")
  end

  if Rails::VERSION::MAJOR >= 5
    describe 'belongs_to' do
      before do
        unless defined?(AdCategory)
          class AdCategory < ActiveRecord::Base
            fields { }
          end
        end

        class Advert < ActiveRecord::Base
          fields do
            name :string, limit: 255, null: true
            category_id :integer, limit: 8
            nullable_category_id :integer, limit: 8, null: true
          end
        end
        up = Generators::DeclareSchema::Migration::Migrator.run.first
        ActiveRecord::Migration.class_eval(up)
      end

      it 'passes through optional: when given' do
        class AdvertBelongsTo < ActiveRecord::Base
          self.table_name = 'adverts'
          fields { }
          reset_column_information
          belongs_to :ad_category, optional: true
        end
        expect(AdvertBelongsTo.reflections['ad_category'].options).to eq(optional: true)
      end

      describe 'contradictory settings' do # contradictory settings are ok during migration
        it 'passes through optional: true, null: false' do
          class AdvertBelongsTo < ActiveRecord::Base
            self.table_name = 'adverts'
            fields { }
            reset_column_information
            belongs_to :ad_category, optional: true, null: false
          end
          expect(AdvertBelongsTo.reflections['ad_category'].options).to eq(optional: true)
          expect(AdvertBelongsTo.field_specs['ad_category_id'].options&.[](:null)).to eq(false)
        end

        it 'passes through optional: false, null: true' do
          class AdvertBelongsTo < ActiveRecord::Base
            self.table_name = 'adverts'
            fields { }
            reset_column_information
            belongs_to :ad_category, optional: false, null: true
          end
          expect(AdvertBelongsTo.reflections['ad_category'].options).to eq(optional: false)
          expect(AdvertBelongsTo.field_specs['ad_category_id'].options&.[](:null)).to eq(true)
        end
      end

      [false, true].each do |nullable|
        context "nullable=#{nullable}" do
          it 'infers optional: from null:' do
            eval <<~EOS
              class AdvertBelongsTo < ActiveRecord::Base
                fields { }
                belongs_to :ad_category, null: #{nullable}
              end
            EOS
            expect(AdvertBelongsTo.reflections['ad_category'].options).to eq(optional: nullable)
            expect(AdvertBelongsTo.field_specs['ad_category_id'].options&.[](:null)).to eq(nullable)
          end

          it 'infers null: from optional:' do
            eval <<~EOS
              class AdvertBelongsTo < ActiveRecord::Base
                fields { }
                belongs_to :ad_category, optional: #{nullable}
              end
            EOS
            expect(AdvertBelongsTo.reflections['ad_category'].options).to eq(optional: nullable)
            expect(AdvertBelongsTo.field_specs['ad_category_id'].options&.[](:null)).to eq(nullable)
          end
        end
      end
    end
  end

  describe 'migration base class' do
    it 'adapts to Rails 4' do
      class Advert < active_record_base_class.constantize
        fields do
          title :string, limit: 100
        end
      end

      Rails::Generators.invoke('declare_schema:migration', %w[-n -m])

      migrations = Dir.glob('db/migrate/*declare_schema_migration*.rb')
      expect(migrations.size).to eq(1), migrations.inspect

      migration_content = File.read(migrations.first)
      first_line = migration_content.split("\n").first
      base_class = first_line.split(' < ').last
      expect(base_class).to eq("(Rails::VERSION::MAJOR >= 5 ? ActiveRecord::Migration[4.2] : ActiveRecord::Migration)")
    end
  end
end
