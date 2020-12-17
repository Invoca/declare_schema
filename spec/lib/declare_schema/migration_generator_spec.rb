# frozen_string_literal: true

require 'rails'

RSpec.describe 'DeclareSchema Migration Generator' do
  before do
    load File.expand_path('prepare_testapp.rb', __dir__)
  end

  # DeclareSchema - Migration Generator
  it 'generates migrations' do
    ## The migration generator -- introduction

    expect(Generators::DeclareSchema::Migration::Migrator.run).to migrate_up("").and migrate_down("")

    class Advert < ActiveRecord::Base
    end

    expect(Generators::DeclareSchema::Migration::Migrator.run).to migrate_up("").and migrate_down("")

    Generators::DeclareSchema::Migration::Migrator.ignore_tables = ["green_fishes"]

    Advert.connection.schema_cache.clear!
    Advert.reset_column_information

    class Advert < ActiveRecord::Base
      fields do
        name :string, limit: 255, null: true
      end
    end

    up, _ = Generators::DeclareSchema::Migration::Migrator.run.tap do |migrations|
      expect(migrations).to(
        migrate_up(<<~EOS.strip)
          create_table :adverts, id: :bigint do |t|
            t.string :name, limit: 255
          end
        EOS
        .and migrate_down("drop_table :adverts")
      )
    end

    ActiveRecord::Migration.class_eval(up)
    expect(Advert.columns.map(&:name)).to eq(["id", "name"])

    if Rails::VERSION::MAJOR < 5
      # Rails 4 sqlite driver doesn't create PK properly. Fix that by dropping and recreating.
      ActiveRecord::Base.connection.execute("drop table adverts")
      ActiveRecord::Base.connection.execute('CREATE TABLE "adverts" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "name" varchar(255))')
    end

    class Advert < ActiveRecord::Base
      fields do
        name :string, limit: 255, null: true
        body :text, null: true
        published_at :datetime, null: true
      end
    end

    Advert.connection.schema_cache.clear!
    Advert.reset_column_information

    expect(migrate).to(
      migrate_up(<<~EOS.strip)
        add_column :adverts, :body, :text
        add_column :adverts, :published_at, :datetime
      EOS
      .and migrate_down(<<~EOS.strip)
        remove_column :adverts, :body
        remove_column :adverts, :published_at
      EOS
    )

    Advert.field_specs.clear # not normally needed
    class Advert < ActiveRecord::Base
      fields do
        name :string, limit: 255, null: true
        body :text, null: true
      end
    end

    expect(migrate).to(
      migrate_up("remove_column :adverts, :published_at").and(
        migrate_down("add_column :adverts, :published_at, :datetime")
      )
    )

    nuke_model_class(Advert)
    class Advert < ActiveRecord::Base
      fields do
        title :string, limit: 255, null: true
        body :text, null: true
      end
    end

    expect(Generators::DeclareSchema::Migration::Migrator.run).to(
      migrate_up(<<~EOS.strip)
        add_column :adverts, :title, :string, limit: 255
        remove_column :adverts, :name
      EOS
      .and migrate_down(<<~EOS.strip)
        remove_column :adverts, :title
        add_column :adverts, :name, :string, limit: 255
      EOS
    )

    expect(Generators::DeclareSchema::Migration::Migrator.run(adverts: { name: :title })).to(
      migrate_up("rename_column :adverts, :name, :title").and(
        migrate_down("rename_column :adverts, :title, :name")
      )
    )

    migrate

    class Advert < ActiveRecord::Base
      fields do
        title :text, null: true
        body :text, null: true
      end
    end

    expect(Generators::DeclareSchema::Migration::Migrator.run).to(
      migrate_up("change_column :adverts, :title, :text").and(
        migrate_down("change_column :adverts, :title, :string, limit: 255")
      )
    )

    class Advert < ActiveRecord::Base
      fields do
        title :string, default: "Untitled", limit: 255, null: true
        body :text, null: true
      end
    end

    expect(migrate).to(
      migrate_up(<<~EOS.strip)
        change_column :adverts, :title, :string, limit: 255, default: "Untitled"
      EOS
      .and migrate_down(<<~EOS.strip)
        change_column :adverts, :title, :string, limit: 255
      EOS
    )

    ### Limits

    class Advert < ActiveRecord::Base
      fields do
        price :integer, null: true, limit: 2
      end
    end

    up, _ = Generators::DeclareSchema::Migration::Migrator.run.tap do |migrations|
      expect(migrations).to migrate_up("add_column :adverts, :price, :integer, limit: 2")
    end

    # Now run the migration, then change the limit:

    ActiveRecord::Migration.class_eval(up)
    class Advert < ActiveRecord::Base
      fields do
        price :integer, null: true, limit: 3
      end
    end

    expect(Generators::DeclareSchema::Migration::Migrator.run).to(
      migrate_up(<<~EOS.strip)
        change_column :adverts, :price, :integer, limit: 3
      EOS
      .and migrate_down(<<~EOS.strip)
        change_column :adverts, :price, :integer, limit: 2
      EOS
    )

    # Note that limit on a decimal column is ignored (use :scale and :precision)

    ActiveRecord::Migration.class_eval("remove_column :adverts, :price")
    class Advert < ActiveRecord::Base
      fields do
        price :decimal, null: true, limit: 4
      end
    end

    expect(Generators::DeclareSchema::Migration::Migrator.run).to migrate_up("add_column :adverts, :price, :decimal")

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

    expect(Generators::DeclareSchema::Migration::Migrator.run).to(
      migrate_up(<<~EOS.strip)
        add_column :adverts, :price, :decimal
        add_column :adverts, :notes, :text, null: false
        add_column :adverts, :description, :text, null: false
      EOS
    )

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

    expect(Generators::DeclareSchema::Migration::Migrator.run).to(
      migrate_up(<<~EOS.strip)
        add_column :adverts, :notes, :text, null: false, limit: 4294967295
        add_column :adverts, :description, :text, null: false, limit: 255
      EOS
    )

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

    expect(Generators::DeclareSchema::Migration::Migrator.run).to(
      migrate_up(<<~EOS.strip)
        change_column :adverts, :description, :text, limit: 4294967295, null: false
      EOS
      .and migrate_down(<<~EOS.strip)
        change_column :adverts, :description, :text
      EOS
    )

    # TODO TECH-4814: The above test should have this output:
    # TODO => "change_column :adverts, :description, :text, limit: 255

    # And migrate to a stated text limit that is the same as the unstated one:

    class Advert < ActiveRecord::Base
      fields do
        description :text, limit: 0xffffffff
      end
    end

    expect(Generators::DeclareSchema::Migration::Migrator.run).to(
      migrate_up(<<~EOS.strip)
        change_column :adverts, :description, :text, limit: 4294967295, null: false
      EOS
      .and migrate_down(<<~EOS.strip)
        change_column :adverts, :description, :text
      EOS
    )
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

    expect(Generators::DeclareSchema::Migration::Migrator.run).to(
      migrate_up(<<~EOS.strip)
        add_column :adverts, :category_id, :integer, limit: 8, null: false

        add_index :adverts, [:category_id], name: 'on_category_id'
      EOS
      .and migrate_down(<<~EOS.strip)
        remove_column :adverts, :category_id

        remove_index :adverts, name: :on_category_id rescue ActiveRecord::StatementInvalid
      EOS
    )

    Advert.field_specs.delete(:category_id)
    Advert.index_definitions.delete_if { |spec| spec.fields==["category_id"] }

    # If you specify a custom foreign key, the migration generator observes that:

    class Category < ActiveRecord::Base; end
    class Advert < ActiveRecord::Base
      fields { }
      belongs_to :category, foreign_key: "c_id", class_name: 'Category'
    end

    expect(Generators::DeclareSchema::Migration::Migrator.run).to(
      migrate_up(<<~EOS.strip)
        add_column :adverts, :c_id, :integer, limit: 8, null: false

        add_index :adverts, [:c_id], name: 'on_c_id'
      EOS
    )

    Advert.field_specs.delete(:c_id)
    Advert.index_definitions.delete_if { |spec| spec.fields == ["c_id"] }

    # You can avoid generating the index by specifying `index: false`

    class Category < ActiveRecord::Base; end
    class Advert < ActiveRecord::Base
      fields { }
      belongs_to :category, index: false
    end

    expect(Generators::DeclareSchema::Migration::Migrator.run).to(
      migrate_up(<<~EOS.strip)
        add_column :adverts, :category_id, :integer, limit: 8, null: false
      EOS
    )

    Advert.field_specs.delete(:category_id)
    Advert.index_definitions.delete_if { |spec| spec.fields == ["category_id"] }

    # You can specify the index name with :index

    class Category < ActiveRecord::Base; end
    class Advert < ActiveRecord::Base
      fields { }
      belongs_to :category, index: 'my_index'
    end

    expect(Generators::DeclareSchema::Migration::Migrator.run).to(
      migrate_up(<<~EOS.strip)
        add_column :adverts, :category_id, :integer, limit: 8, null: false

        add_index :adverts, [:category_id], name: 'my_index'
      EOS
    )

    Advert.field_specs.delete(:category_id)
    Advert.index_definitions.delete_if { |spec| spec.fields == ["category_id"] }

    ### Timestamps and Optimimistic Locking

    # `updated_at` and `created_at` can be declared with the shorthand `timestamps`.
    # Similarly, `lock_version` can be declared with the "shorthand" `optimimistic_lock`.

    class Advert < ActiveRecord::Base
      fields do
        timestamps
        optimistic_lock
      end
    end

    expect(Generators::DeclareSchema::Migration::Migrator.run).to(
      migrate_up(<<~EOS.strip)
        add_column :adverts, :created_at, :datetime
        add_column :adverts, :updated_at, :datetime
        add_column :adverts, :lock_version, :integer, null: false, default: 1
      EOS
      .and migrate_down(<<~EOS.strip)
        remove_column :adverts, :created_at
        remove_column :adverts, :updated_at
        remove_column :adverts, :lock_version
      EOS
    )

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

    expect(Generators::DeclareSchema::Migration::Migrator.run).to(
      migrate_up(<<~EOS.strip)
        add_column :adverts, :title, :string, limit: 255

        add_index :adverts, [:title], name: 'on_title'
      EOS
    )

    Advert.index_definitions.delete_if { |spec| spec.fields==["title"] }

    # You can ask for a unique index

    class Advert < ActiveRecord::Base
      fields do
        title :string, index: true, unique: true, null: true, limit: 255
      end
    end

    expect(Generators::DeclareSchema::Migration::Migrator.run).to(
      migrate_up(<<~EOS.strip)
        add_column :adverts, :title, :string, limit: 255

        add_index :adverts, [:title], unique: true, name: 'on_title'
      EOS
    )

    Advert.index_definitions.delete_if { |spec| spec.fields == ["title"] }

    # You can specify the name for the index

    class Advert < ActiveRecord::Base
      fields do
        title :string, index: 'my_index', limit: 255, null: true
      end
    end

    expect(Generators::DeclareSchema::Migration::Migrator.run).to(
      migrate_up(<<~EOS.strip)
        add_column :adverts, :title, :string, limit: 255

        add_index :adverts, [:title], name: 'my_index'
      EOS
    )

    Advert.index_definitions.delete_if { |spec| spec.fields==["title"] }

    # You can ask for an index outside of the fields block

    class Advert < ActiveRecord::Base
      index :title
    end

    expect(Generators::DeclareSchema::Migration::Migrator.run).to(
      migrate_up(<<~EOS.strip)
        add_column :adverts, :title, :string, limit: 255

        add_index :adverts, [:title], name: 'on_title'
      EOS
    )

    Advert.index_definitions.delete_if { |spec| spec.fields == ["title"] }

    # The available options for the index function are `:unique` and `:name`

    class Advert < ActiveRecord::Base
      index :title, unique: true, name: 'my_index'
    end

    expect(Generators::DeclareSchema::Migration::Migrator.run).to(
      migrate_up(<<~EOS.strip)
        add_column :adverts, :title, :string, limit: 255

        add_index :adverts, [:title], unique: true, name: 'my_index'
      EOS
    )

    Advert.index_definitions.delete_if { |spec| spec.fields == ["title"] }

    # You can create an index on more than one field

    class Advert < ActiveRecord::Base
      index [:title, :category_id]
    end

    expect(Generators::DeclareSchema::Migration::Migrator.run).to(
      migrate_up(<<~EOS.strip)
        add_column :adverts, :title, :string, limit: 255

        add_index :adverts, [:title, :category_id], name: 'on_title_and_category_id'
      EOS
    )

    Advert.index_definitions.delete_if { |spec| spec.fields==["title", "category_id"] }

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

    expect(Generators::DeclareSchema::Migration::Migrator.run("adverts" => "ads")).to(
      migrate_up(<<~EOS.strip)
        rename_table :adverts, :ads

        add_column :ads, :title, :string, limit: 255
        add_column :ads, :body, :text

        add_index :ads, [:id], unique: true, name: 'PRIMARY'
      EOS
      .and migrate_down(<<~EOS.strip)
        remove_column :ads, :title
        remove_column :ads, :body

        rename_table :ads, :adverts

        add_index :adverts, [:id], unique: true, name: 'PRIMARY'
      EOS
    )

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

    expect(Generators::DeclareSchema::Migration::Migrator.run("adverts" => "advertisements")).to(
      migrate_up(<<~EOS.strip)
        rename_table :adverts, :advertisements

        add_column :advertisements, :title, :string, limit: 255
        add_column :advertisements, :body, :text
        remove_column :advertisements, :name

        add_index :advertisements, [:id], unique: true, name: 'PRIMARY'
      EOS
      .and migrate_down(<<~EOS.strip)
        remove_column :advertisements, :title
        remove_column :advertisements, :body
        add_column :adverts, :name, :string, limit: 255

        rename_table :advertisements, :adverts

        add_index :adverts, [:id], unique: true, name: 'PRIMARY'
      EOS
    )

    ### Drop a table

    nuke_model_class(Advertisement)

    # If you delete a model, the migration generator will create a `drop_table` migration.

    # Dropping tables is where the automatic down-migration really comes in handy:

    rails4_table_create = <<~EOS.strip
      create_table "adverts", force: :cascade do |t|
        t.string "name", limit: 255
      end
    EOS

    rails5_table_create = <<~EOS.strip
      create_table "adverts", id: :integer, force: :cascade do |t|
        t.string "name", limit: 255
      end
    EOS

    expect(Generators::DeclareSchema::Migration::Migrator.run).to(
      migrate_up(<<~EOS.strip)
        drop_table :adverts
      EOS
      .and migrate_down(Rails::VERSION::MAJOR >= 5 ? rails5_table_create : rails4_table_create)
    )

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

    up, _ = Generators::DeclareSchema::Migration::Migrator.run do |migrations|
      expect(migrations).to(
        migrate_up(<<~EOS.strip)
          add_column :adverts, :type, :string, limit: 255

          add_index :adverts, [:type], name: 'on_type'
        EOS
        .and migrate_down(<<~EOS.strip)
          remove_column :adverts, :type

          remove_index :adverts, name: :on_type rescue ActiveRecord::StatementInvalid
        EOS
      )
    end

    Advert.field_specs.delete(:type)
    nuke_model_class(SuperFancyAdvert)
    nuke_model_class(FancyAdvert)
    Advert.index_definitions.delete_if { |spec| spec.fields==["type"] }

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

    expect(Generators::DeclareSchema::Migration::Migrator.run(adverts: { title: :name })).to(
      migrate_up(<<~EOS.strip)
        rename_column :adverts, :title, :name
        change_column :adverts, :name, :string, limit: 255, default: "No Name"
      EOS
      .and migrate_down(<<~EOS.strip)
        rename_column :adverts, :name, :title
        change_column :adverts, :title, :string, limit: 255, default: "Untitled"
      EOS
    )

    ### Rename a table and add a column

    nuke_model_class(Advert)
    class Ad < ActiveRecord::Base
      fields do
        title      :string, default: "Untitled", limit: 255
        body       :text, null: true
        created_at :datetime
      end
    end

    expect(Generators::DeclareSchema::Migration::Migrator.run(adverts: :ads)).to(
      migrate_up(<<~EOS.strip)
        rename_table :adverts, :ads

        add_column :ads, :created_at, :datetime, null: false
        change_column :ads, :title, :string, limit: 255, null: false, default: \"Untitled\"

        add_index :ads, [:id], unique: true, name: 'PRIMARY'
      EOS
    )

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

    expect(Generators::DeclareSchema::Migration::Migrator.run(adverts: { id: :advert_id })).to(
      migrate_up(<<~EOS.strip)
        rename_column :adverts, :id, :advert_id

        add_index :adverts, [:advert_id], unique: true, name: 'PRIMARY'
      EOS
    )

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

  describe 'serialize' do
    before do
      class Ad < ActiveRecord::Base
        @serialize_args = []

        class << self
          attr_reader :serialize_args

          def serialize(*args)
            @serialize_args << args
          end
        end
      end
    end

    describe 'untyped' do
      it 'allows serialize: true' do
        class Ad < ActiveRecord::Base
          fields do
            allow_list :text, limit: 0xFFFF, serialize: true
          end
        end

        expect(Ad.serialize_args).to eq([[:allow_list]])
      end

      it 'converts defaults with .to_yaml' do
        class Ad < ActiveRecord::Base
          fields do
            allow_list :string, limit: 255, serialize: true, null: true, default: []
            allow_hash :string, limit: 255, serialize: true, null: true, default: {}
            allow_string :string, limit: 255, serialize: true, null: true, default: ['abc']
            allow_null :string, limit: 255, serialize: true, null: true, default: nil
          end
        end

        expect(Ad.field_specs['allow_list'].default).to eq("--- []\n")
        expect(Ad.field_specs['allow_hash'].default).to eq("--- {}\n")
        expect(Ad.field_specs['allow_string'].default).to eq("---\n- abc\n")
        expect(Ad.field_specs['allow_null'].default).to eq(nil)
      end
    end

    describe 'Array' do
      it 'allows serialize: Array' do
        class Ad < ActiveRecord::Base
          fields do
            allow_list :string, limit: 255, serialize: Array, null: true
          end
        end

        expect(Ad.serialize_args).to eq([[:allow_list, Array]])
      end

      it 'allows Array defaults' do
        class Ad < ActiveRecord::Base
          fields do
            allow_list :string, limit: 255, serialize: Array, null: true, default: [2]
            allow_string :string, limit: 255, serialize: Array, null: true, default: ['abc']
            allow_empty :string, limit: 255, serialize: Array, null: true, default: []
            allow_null :string, limit: 255, serialize: Array, null: true, default: nil
          end
        end

        expect(Ad.field_specs['allow_list'].default).to eq("---\n- 2\n")
        expect(Ad.field_specs['allow_string'].default).to eq("---\n- abc\n")
        expect(Ad.field_specs['allow_empty'].default).to eq(nil)
        expect(Ad.field_specs['allow_null'].default).to eq(nil)
      end
    end

    describe 'Hash' do
      it 'allows serialize: Hash' do
        class Ad < ActiveRecord::Base
          fields do
            allow_list :string, limit: 255, serialize: Hash, null: true
          end
        end

        expect(Ad.serialize_args).to eq([[:allow_list, Hash]])
      end

      it 'allows Hash defaults' do
        class Ad < ActiveRecord::Base
          fields do
            allow_loc :string, limit: 255, serialize: Hash, null: true, default: { 'state' => 'CA' }
            allow_hash :string, limit: 255, serialize: Hash, null: true, default: {}
            allow_null :string, limit: 255, serialize: Hash, null: true, default: nil
          end
        end

        expect(Ad.field_specs['allow_loc'].default).to eq("---\nstate: CA\n")
        expect(Ad.field_specs['allow_hash'].default).to eq(nil)
        expect(Ad.field_specs['allow_null'].default).to eq(nil)
      end
    end

    describe 'JSON' do
      it 'allows serialize: JSON' do
        class Ad < ActiveRecord::Base
          fields do
            allow_list :string, limit: 255, serialize: JSON
          end
        end

        expect(Ad.serialize_args).to eq([[:allow_list, JSON]])
      end

      it 'allows JSON defaults' do
        class Ad < ActiveRecord::Base
          fields do
            allow_hash :string, limit: 255, serialize: JSON, null: true, default: { 'state' => 'CA' }
            allow_empty_array :string, limit: 255, serialize: JSON, null: true, default: []
            allow_empty_hash :string, limit: 255, serialize: JSON, null: true, default: {}
            allow_null :string, limit: 255, serialize: JSON, null: true, default: nil
          end
        end

        expect(Ad.field_specs['allow_hash'].default).to eq("{\"state\":\"CA\"}")
        expect(Ad.field_specs['allow_empty_array'].default).to eq("[]")
        expect(Ad.field_specs['allow_empty_hash'].default).to eq("{}")
        expect(Ad.field_specs['allow_null'].default).to eq(nil)
      end
    end

    class ValueClass
      delegate :present?, :inspect, to: :@value

      def initialize(value)
        @value = value
      end

      class << self
        def dump(object)
          if object&.present?
            object.inspect
          end
        end

        def load(serialized)
          if serialized
            raise 'not used ???'
          end
        end
      end
    end

    describe 'custom coder' do
      it 'allows serialize: ValueClass' do
        class Ad < ActiveRecord::Base
          fields do
            allow_list :string, limit: 255, serialize: ValueClass
          end
        end

        expect(Ad.serialize_args).to eq([[:allow_list, ValueClass]])
      end

      it 'allows ValueClass defaults' do
        class Ad < ActiveRecord::Base
          fields do
            allow_hash :string, limit: 255, serialize: ValueClass, null: true, default: ValueClass.new([2])
            allow_empty_array :string, limit: 255, serialize: ValueClass, null: true, default: ValueClass.new([])
            allow_null :string, limit: 255, serialize: ValueClass, null: true, default: nil
          end
        end

        expect(Ad.field_specs['allow_hash'].default).to eq("[2]")
        expect(Ad.field_specs['allow_empty_array'].default).to eq(nil)
        expect(Ad.field_specs['allow_null'].default).to eq(nil)
      end
    end

    it 'disallows serialize: with a non-string column type' do
      expect do
        class Ad < ActiveRecord::Base
          fields do
            allow_list :integer, limit: 8, serialize: true
          end
        end
      end.to raise_exception(ArgumentError, /must be :string or :text/)
    end
  end

  context "for Rails #{Rails::VERSION::MAJOR}" do
    if Rails::VERSION::MAJOR >= 5
      let(:optional_true) { { optional: true } }
      let(:optional_false) { { optional: false } }
    else
      let(:optional_true) { {} }
      let(:optional_false) { {} }
    end
    let(:optional_flag) { { false => optional_false, true => optional_true } }

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
        expect(AdvertBelongsTo.reflections['ad_category'].options).to eq(optional_true)
      end

      describe 'contradictory settings' do # contradictory settings are ok--for example, during migration
        it 'passes through optional: true, null: false' do
          class AdvertBelongsTo < ActiveRecord::Base
            self.table_name = 'adverts'
            fields { }
            reset_column_information
            belongs_to :ad_category, optional: true, null: false
          end
          expect(AdvertBelongsTo.reflections['ad_category'].options).to eq(optional_true)
          expect(AdvertBelongsTo.field_specs['ad_category_id'].options&.[](:null)).to eq(false)
        end

        it 'passes through optional: false, null: true' do
          class AdvertBelongsTo < ActiveRecord::Base
            self.table_name = 'adverts'
            fields { }
            reset_column_information
            belongs_to :ad_category, optional: false, null: true
          end
          expect(AdvertBelongsTo.reflections['ad_category'].options).to eq(optional_false)
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
            expect(AdvertBelongsTo.reflections['ad_category'].options).to eq(optional_flag[nullable])
            expect(AdvertBelongsTo.field_specs['ad_category_id'].options&.[](:null)).to eq(nullable)
          end

          it 'infers null: from optional:' do
            eval <<~EOS
              class AdvertBelongsTo < ActiveRecord::Base
                fields { }
                belongs_to :ad_category, optional: #{nullable}
              end
            EOS
            expect(AdvertBelongsTo.reflections['ad_category'].options).to eq(optional_flag[nullable])
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

      generate_migrations '-n', '-m'

      migrations = Dir.glob('db/migrate/*declare_schema_migration*.rb')
      expect(migrations.size).to eq(1), migrations.inspect

      migration_content = File.read(migrations.first)
      first_line = migration_content.split("\n").first
      base_class = first_line.split(' < ').last
      expect(base_class).to eq("(Rails::VERSION::MAJOR >= 5 ? ActiveRecord::Migration[4.2] : ActiveRecord::Migration)")
    end
  end

  context 'Does not generate migrations' do
    it 'for aliased fields bigint -> integer limit 8' do
      class Advert < ActiveRecord::Base
        fields do
          price :bigint
        end
      end

      generate_migrations '-n', '-m'

      migrations = Dir.glob('db/migrate/*declare_schema_migration*.rb')
      expect(migrations.size).to eq(1), migrations.inspect

      class Advert < ActiveRecord::Base
        fields do
          price :integer, limit: 8
        end
      end

      expect { generate_migrations '-n', '-g' }.to output("Database and models match -- nothing to change\n").to_stdout
    end
  end
end
