# frozen_string_literal: true

begin
  require 'mysql2'
rescue LoadError
end

begin
  require 'sqlite3'
rescue LoadError
end

RSpec.describe 'DeclareSchema Migration Generator' do
  before do
    load File.expand_path('prepare_testapp.rb', __dir__)
  end
  let(:text_limit) do
    if defined?(Mysql2)
      ", limit: 4294967295"
    end
  end
  let(:charset_and_collation) do
    if defined?(Mysql2)
      ', charset: "utf8mb4", collation: "utf8mb4_bin"'
    end
  end
  let(:create_table_charset_and_collation) do
    if defined?(Mysql2)
      ", options: \"CHARACTER SET utf8mb4 COLLATE utf8mb4_bin\""
    end
  end
  let(:datetime_precision) do
    if defined?(Mysql2)
      ', precision: 0'
    end
  end
  let(:table_options) do
    if defined?(Mysql2)
      ", options: \"#{'ENGINE=InnoDB ' if ActiveSupport::VERSION::MAJOR == 5}DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin\"" +
        if ActiveSupport::VERSION::MAJOR >= 6
          ', charset: "utf8mb4", collation: "utf8mb4_bin"'
        else
          ''
        end
    else
      ", id: :integer"
    end
  end
  let(:lock_version_limit) do
    if defined?(Mysql2)
      ", limit: 4"
    else
      ''
    end
  end

  context 'Using declare_schema' do
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
        declare_schema do
          string :name, limit: 250, null: true
        end
      end

      up, _ = Generators::DeclareSchema::Migration::Migrator.run.tap do |migrations|
        expect(migrations).to(
          migrate_up(<<~EOS.strip)
            create_table :adverts, id: :bigint#{create_table_charset_and_collation} do |t|
              t.string :name, limit: 250, null: true#{charset_and_collation}
            end
          EOS
          .and migrate_down("drop_table :adverts")
        )
      end

      ActiveRecord::Migration.class_eval(up)
      expect(Advert.columns.map(&:name)).to eq(["id", "name"])

      class Advert < ActiveRecord::Base
        declare_schema do
          string :name, limit: 250, null: true
          text :body, null: true
          datetime :published_at, null: true
        end
      end

      Advert.connection.schema_cache.clear!
      Advert.reset_column_information

      expect(migrate).to(
        migrate_up(<<~EOS.strip)
          add_column :adverts, :body, :text#{text_limit}, null: true#{charset_and_collation}
          add_column :adverts, :published_at, :datetime, null: true
        EOS
        .and migrate_down(<<~EOS.strip)
            remove_column :adverts, :published_at
            remove_column :adverts, :body
        EOS
      )

      Advert.field_specs.clear # not normally needed
      class Advert < ActiveRecord::Base
        declare_schema do
          string :name, limit: 250, null: true
          text :body, null: true
        end
      end

      expect(migrate).to(
          migrate_up("remove_column :adverts, :published_at").and(
              migrate_down("add_column :adverts, :published_at, :datetime#{datetime_precision}, null: true")
          )
      )

      nuke_model_class(Advert)
      class Advert < ActiveRecord::Base
        declare_schema do
          string :title, limit: 250, null: true
          text :body, null: true
        end
      end

      expect(Generators::DeclareSchema::Migration::Migrator.run).to(
        migrate_up(<<~EOS.strip)
          add_column :adverts, :title, :string, limit: 250, null: true#{charset_and_collation}
          remove_column :adverts, :name
        EOS
        .and migrate_down(<<~EOS.strip)
            add_column :adverts, :name, :string, limit: 250, null: true#{charset_and_collation}
            remove_column :adverts, :title
        EOS
      )

      expect(Generators::DeclareSchema::Migration::Migrator.run(adverts: { name: :title })).to(
          migrate_up("rename_column :adverts, :name, :title").and(
              migrate_down("rename_column :adverts, :title, :name")
          )
      )

      migrate

      class Advert < ActiveRecord::Base
        declare_schema do
          text :title, null: true
          text :body, null: true
        end
      end

      expect(Generators::DeclareSchema::Migration::Migrator.run).to(
          migrate_up("change_column :adverts, :title, :text#{text_limit}, null: true#{charset_and_collation}").and(
              migrate_down("change_column :adverts, :title, :string, limit: 250, null: true#{charset_and_collation}")
          )
      )

      class Advert < ActiveRecord::Base
        declare_schema do
          string :title, default: "Untitled", limit: 250, null: true
          text :body, null: true
        end
      end

      expect(migrate).to(
          migrate_up(<<~EOS.strip)
          change_column :adverts, :title, :string, limit: 250, null: true, default: "Untitled"#{charset_and_collation}
          EOS
              .and migrate_down(<<~EOS.strip)
              change_column :adverts, :title, :string, limit: 250, null: true#{charset_and_collation}
      EOS
      )

      ### Limits

      class Advert < ActiveRecord::Base
        declare_schema do
          integer :price, null: true, limit: 2
        end
      end

      up, _ = Generators::DeclareSchema::Migration::Migrator.run.tap do |migrations|
        expect(migrations).to migrate_up("add_column :adverts, :price, :integer, limit: 2, null: true")
      end

      # Now run the migration, then change the limit:

      ActiveRecord::Migration.class_eval(up)
      class Advert < ActiveRecord::Base
        declare_schema do
          integer :price, null: true, limit: 3
        end
      end

      expect(Generators::DeclareSchema::Migration::Migrator.run).to(
          migrate_up(<<~EOS.strip)
          change_column :adverts, :price, :integer, limit: 3, null: true
          EOS
              .and migrate_down(<<~EOS.strip)
              change_column :adverts, :price, :integer, limit: 2, null: true
      EOS
      )

      ActiveRecord::Migration.class_eval("remove_column :adverts, :price")
      class Advert < ActiveRecord::Base
        declare_schema do
          decimal :price, precision: 4, scale: 1, null: true
        end
      end

      # Limits are generally not needed for `text` fields, because by default, `text` fields will use the maximum size
      # allowed for that database type (0xffffffff for LONGTEXT in MySQL unlimited in Postgres, 1 billion in Sqlite).
      # If a `limit` is given, it will only be used in MySQL, to choose the smallest TEXT field that will accommodate
      # that limit (0xff for TINYTEXT, 0xffff for TEXT, 0xffffff for MEDIUMTEXT, 0xffffffff for LONGTEXT).

      if defined?(SQLite3)
        expect(::DeclareSchema::Model::FieldSpec.mysql_text_limits?).to be_falsey
      end

      class Advert < ActiveRecord::Base
        declare_schema do
          text :notes
          text :description, limit: 30000
        end
      end

      expect(Generators::DeclareSchema::Migration::Migrator.run).to(
          migrate_up(<<~EOS.strip)
          add_column :adverts, :price, :decimal, precision: 4, scale: 1, null: true
          add_column :adverts, :notes, :text#{text_limit}, null: false#{charset_and_collation}
          add_column :adverts, :description, :text#{', limit: 65535' if defined?(Mysql2)}, null: false#{charset_and_collation}
      EOS
      )

      Advert.field_specs.delete :price
      Advert.field_specs.delete :notes
      Advert.field_specs.delete :description

      # In MySQL, limits are applied, rounded up:

      if defined?(Mysql2)
        expect(::DeclareSchema::Model::FieldSpec.mysql_text_limits?).to be_truthy

        class Advert < ActiveRecord::Base
          declare_schema do
            text :notes
            text :description, limit: 250
          end
        end

        expect(Generators::DeclareSchema::Migration::Migrator.run).to(
            migrate_up(<<~EOS.strip)
            add_column :adverts, :notes, :text, limit: 4294967295, null: false#{charset_and_collation}
            add_column :adverts, :description, :text, limit: 255, null: false#{charset_and_collation}
        EOS
        )

        Advert.field_specs.delete :notes

        # Limits that are too high for MySQL will raise an exception.

        expect do
          class Advert < ActiveRecord::Base
            declare_schema do
              text :notes
              text :description, limit: 0x1_0000_0000
            end
          end
        end.to raise_exception(ArgumentError, "limit of 4294967296 is too large for MySQL")

        Advert.field_specs.delete :notes

        # And in MySQL, unstated text limits are treated as the maximum (LONGTEXT) limit.

        # To start, we'll set the database schema for `description` to match the above limit of 250.

        Advert.connection.execute "ALTER TABLE adverts ADD COLUMN description TINYTEXT"
        Advert.connection.schema_cache.clear!
        Advert.reset_column_information
        expect(Advert.connection.tables - Generators::DeclareSchema::Migration::Migrator.always_ignore_tables).
            to eq(["adverts"])
        expect(Advert.columns.map(&:name)).to eq(["id", "body", "title", "description"])

        # Now migrate to an unstated text limit:

        class Advert < ActiveRecord::Base
          declare_schema do
            text :description
          end
        end

        expect(Generators::DeclareSchema::Migration::Migrator.run).to(
            migrate_up(<<~EOS.strip)
            change_column :adverts, :description, :text, limit: 4294967295, null: false#{charset_and_collation}
            EOS
                .and migrate_down(<<~EOS.strip)
                change_column :adverts, :description, :text#{', limit: 255' if defined?(Mysql2)}, null: true#{charset_and_collation}
        EOS
        )

        # And migrate to a stated text limit that is the same as the unstated one:

        class Advert < ActiveRecord::Base
          declare_schema do
            text :description, limit: 0xffffffff
          end
        end

        expect(Generators::DeclareSchema::Migration::Migrator.run).to(
            migrate_up(<<~EOS.strip)
            change_column :adverts, :description, :text, limit: 4294967295, null: false#{charset_and_collation}
            EOS
                .and migrate_down(<<~EOS.strip)
                change_column :adverts, :description, :text#{', limit: 255' if defined?(Mysql2)}, null: true#{charset_and_collation}
        EOS
        )
      end

      Advert.field_specs.clear
      Advert.connection.schema_cache.clear!
      Advert.reset_column_information
      class Advert < ActiveRecord::Base
        declare_schema do
          string :name, limit: 250, null: true
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
        declare_schema do
          string :name, limit: 250, null: true
        end
        belongs_to :category
      end

      expect(Generators::DeclareSchema::Migration::Migrator.run).to(
        migrate_up(<<~EOS.strip)
          add_column :adverts, :category_id, :integer, limit: 8, null: false
          add_index :adverts, [:category_id], name: :index_adverts_on_category_id
          #{"add_foreign_key :adverts, :categories, column: :category_id, name: :index_adverts_on_category_id\n" if defined?(Mysql2)}
        EOS
        .and migrate_down(<<~EOS.strip)
            #{"remove_foreign_key :adverts, name: :index_adverts_on_category_id" if defined?(Mysql2)}
            remove_index :adverts, name: :index_adverts_on_category_id
            remove_column :adverts, :category_id
        EOS
      )

      Advert.field_specs.delete(:category_id)
      Advert.index_definitions.delete_if { |spec| spec.fields == ["category_id"] }

      # If you specify a custom foreign key, the migration generator observes that:

      class Category < ActiveRecord::Base; end
      class Advert < ActiveRecord::Base
        declare_schema { }
        belongs_to :category, foreign_key: "c_id", class_name: 'Category'
      end

      expect(Generators::DeclareSchema::Migration::Migrator.run).to(
        migrate_up(<<~EOS.strip)
          add_column :adverts, :c_id, :integer, limit: 8, null: false
          add_index :adverts, [:c_id], name: :index_adverts_on_c_id
          #{"add_foreign_key :adverts, :categories, column: :category_id, name: :index_adverts_on_category_id\n" +
            "add_foreign_key :adverts, :categories, column: :c_id, name: :index_adverts_on_c_id" if defined?(Mysql2)}
        EOS
      )

      Advert.field_specs.delete(:c_id)
      Advert.index_definitions.delete_if { |spec| spec.fields == ["c_id"] }
      Advert.constraint_definitions.delete_if { |spec| spec.foreign_key_column == "c_id" }

      # You can avoid generating the index by specifying `index: false`

      class Category < ActiveRecord::Base; end
      class Advert < ActiveRecord::Base
        declare_schema { }
        belongs_to :category, index: false
      end

      expect(Generators::DeclareSchema::Migration::Migrator.run).to(
        migrate_up(<<~EOS.strip)
          add_column :adverts, :category_id, :integer, limit: 8, null: false
          #{"add_foreign_key :adverts, :categories, column: :category_id, name: :index_adverts_on_category_id" if defined?(Mysql2)}
       EOS
      )

      Advert.field_specs.delete(:category_id)
      Advert.index_definitions.delete_if { |spec| spec.fields == ["category_id"] }
      Advert.constraint_definitions.delete_if { |spec| spec.foreign_key_column == "category_id" }

      # You can specify the index name with index: 'name'

      class Category < ActiveRecord::Base; end
      class Advert < ActiveRecord::Base
        declare_schema { }
        belongs_to :category, index: 'my_index'
      end

      expect(Generators::DeclareSchema::Migration::Migrator.run).to(
        migrate_up(<<~EOS.strip)
          add_column :adverts, :category_id, :integer, limit: 8, null: false
          add_index :adverts, [:category_id], name: :my_index
          #{"add_foreign_key :adverts, :categories, column: :category_id, name: :my_index" if defined?(Mysql2)}
        EOS
      )

      Advert.field_specs.delete(:category_id)
      Advert.index_definitions.delete_if { |spec| spec.fields == ["category_id"] }
      Advert.constraint_definitions.delete_if { |spec| spec.foreign_key_column == "category_id" }

      ### Timestamps and Optimimistic Locking

      # `updated_at` and `created_at` can be declared with the shorthand `timestamps`.
      # Similarly, `lock_version` can be declared with the "shorthand" `optimimistic_lock`.

      class Advert < ActiveRecord::Base
        declare_schema do
          timestamps
          optimistic_lock
        end
      end

      expect(Generators::DeclareSchema::Migration::Migrator.run).to(
        migrate_up(<<~EOS.strip)
          add_column :adverts, :created_at, :datetime, null: true
          add_column :adverts, :updated_at, :datetime, null: true
          add_column :adverts, :lock_version, :integer#{lock_version_limit}, null: false, default: 1
        EOS
        .and migrate_down(<<~EOS.strip)
            remove_column :adverts, :lock_version
            remove_column :adverts, :updated_at
            remove_column :adverts, :created_at
        EOS
      )

      Advert.field_specs.delete(:updated_at)
      Advert.field_specs.delete(:created_at)
      Advert.field_specs.delete(:lock_version)

      ### Indices

      # You can add an index to a field definition

      class Advert < ActiveRecord::Base
        declare_schema do
          string :title, index: true, limit: 250, null: true
        end
        belongs_to :category, index: 'my_index', unique: false
      end

      expect(Generators::DeclareSchema::Migration::Migrator.run).to(
        migrate_up(<<~EOS.strip)
          add_column :adverts, :title, :string, limit: 250, null: true#{charset_and_collation}
          add_column :adverts, :category_id, :integer, limit: 8, null: false
          add_index :adverts, [:title], name: :index_adverts_on_title
          add_index :adverts, [:category_id], name: :my_index
          #{"add_foreign_key :adverts, :categories, column: :category_id, name: :my_index" if defined?(Mysql2)}
        EOS
      )

      Advert.field_specs.delete(:category_id)
      Advert.index_definitions.delete_if { |spec| spec.fields == ["title"] || spec.fields == ["category_id"] }
      Advert.constraint_definitions.delete_if { |spec| spec.foreign_key_column == "category_id" }

      # You can ask for a unique index (deprecated syntax; use index: { unique: true } instead).

      class Advert < ActiveRecord::Base
        declare_schema do
          string :title, index: true, unique: true, null: true, limit: 250
        end
      end

      expect(Generators::DeclareSchema::Migration::Migrator.run).to(
        migrate_up(<<~EOS.strip)
          add_column :adverts, :title, :string, limit: 250, null: true#{charset_and_collation}
          add_index :adverts, [:title], name: :index_adverts_on_title, unique: true
        EOS
      )

      Advert.index_definitions.delete_if { |spec| spec.fields == ["title"] }

      # You can specify the name for the index

      class Advert < ActiveRecord::Base
        declare_schema do
          string :title, index: 'my_index', limit: 250, null: true
        end
      end

      expect(Generators::DeclareSchema::Migration::Migrator.run).to(
        migrate_up(<<~EOS.strip)
          add_column :adverts, :title, :string, limit: 250, null: true#{charset_and_collation}
          add_index :adverts, [:title], name: :my_index
        EOS
      )

      Advert.index_definitions.delete_if { |spec| spec.fields == ["title"] }

      # You can ask for an index outside of the fields block

      class Advert < ActiveRecord::Base
        declare_schema do
          string :title, limit: 250, null: true
        end
        index :title
      end

      expect(Generators::DeclareSchema::Migration::Migrator.run).to(
        migrate_up(<<~EOS.strip)
          add_column :adverts, :title, :string, limit: 250, null: true#{charset_and_collation}
          add_index :adverts, [:title], name: :index_adverts_on_title
        EOS
      )

      Advert.index_definitions.delete_if { |spec| spec.fields == ["title"] }

      # The available options for the index function are :unique, :name, :where, and :length.

      class Advert < ActiveRecord::Base
        index :title, unique: false, name: 'my_index', length: 10
      end

      expect(Generators::DeclareSchema::Migration::Migrator.run).to(
        migrate_up(<<~EOS.strip)
          add_column :adverts, :title, :string, limit: 250, null: true#{charset_and_collation}
          add_index :adverts, [:title], name: :my_index, length: { title: 10 }
        EOS
      )

      Advert.index_definitions.delete_if { |spec| spec.fields == ["title"] }

      # You can create an index on more than one field

      class Advert < ActiveRecord::Base
        index [:title, :category_id]
      end

      expect(Generators::DeclareSchema::Migration::Migrator.run).to(
        migrate_up(<<~EOS.strip)
          add_column :adverts, :title, :string, limit: 250, null: true#{charset_and_collation}
          add_index :adverts, [:title, :category_id], name: :index_adverts_on_title_and_category_id
        EOS
      )

      Advert.index_definitions.delete_if { |spec| spec.fields == ["title", "category_id"] }

      # Finally, you can specify that the migration generator should completely ignore an
      # index by passing its name to ignore_index in the model.
      # This is helpful for preserving indices that can't be automatically generated, such as prefix indices in MySQL.

      ### Rename a table

      # The migration generator respects the `set_table_name` declaration, although as before, we need to explicitly tell the generator that we want a rename rather than a create and a drop.

      class Advert < ActiveRecord::Base
        self.table_name = "ads"
        declare_schema do
          string :title, limit: 250, null: true
          text :body, null: true
        end
      end

      Advert.connection.schema_cache.clear!
      Advert.reset_column_information

      expect(Generators::DeclareSchema::Migration::Migrator.run(adverts: "ads")).to(
        migrate_up(<<~EOS.strip)
          rename_table :adverts, :ads
          add_column :ads, :title, :string, limit: 250, null: true#{charset_and_collation}
          add_column :ads, :body, :text#{', limit: 4294967295' if defined?(Mysql2)}, null: true#{charset_and_collation}
        EOS
          .and migrate_down(<<~EOS.strip)
            remove_column :ads, :body
            remove_column :ads, :title
            rename_table :ads, :adverts
          EOS
      )

      # Set the table name back to what it should be and confirm we're in sync:

      nuke_model_class(Advert)

      class Advert < ActiveRecord::Base
        self.table_name = "adverts"
      end

      expect(Generators::DeclareSchema::Migration::Migrator.run).to eq(["", ""])

      ### Rename a table

      # As with renaming columns, we have to tell the migration generator about the rename. Here we create a new class 'Advertisement', and tell ActiveRecord to forget about the Advert class. This requires code that shouldn't be shown to impressionable children.

      nuke_model_class(Advert)

      class Advertisement < ActiveRecord::Base
        declare_schema do
          string :title, limit: 250, null: true
          text :body, null: true
        end
      end

      expect(Generators::DeclareSchema::Migration::Migrator.run(adverts: "advertisements")).to(
        migrate_up(<<~EOS.strip)
          rename_table :adverts, :advertisements
          add_column :advertisements, :title, :string, limit: 250, null: true#{charset_and_collation}
          add_column :advertisements, :body, :text#{', limit: 4294967295' if defined?(Mysql2)}, null: true#{charset_and_collation}
          remove_column :advertisements, :name
        EOS
        .and migrate_down(<<~EOS.strip)
            add_column :advertisements, :name, :string, limit: 250, null: true#{charset_and_collation}
            remove_column :advertisements, :body
            remove_column :advertisements, :title
            rename_table :advertisements, :adverts
        EOS
      )

      ### Drop a table

      nuke_model_class(Advertisement)

      # If you delete a model, the migration generator will create a `drop_table` migration.

      # Dropping tables is where the automatic down-migration really comes in handy:

      expect(Generators::DeclareSchema::Migration::Migrator.run).to(
        migrate_up(<<~EOS.strip)
          drop_table :adverts
        EOS
        .and migrate_down(<<~EOS.strip)
            create_table "adverts"#{table_options}, force: :cascade do |t|
              t.string "name", limit: 250#{charset_and_collation}
            end
        EOS
      )

      ## STI

      ### Adding an STI subclass

      # Adding a subclass or two should introduce the 'type' column and no other changes

      class Advert < ActiveRecord::Base
        declare_schema do
          text :body, null: true
          string :title, default: "Untitled", limit: 250, null: true
        end
      end
      up = Generators::DeclareSchema::Migration::Migrator.run.first
      ActiveRecord::Migration.class_eval(up)

      class FancyAdvert < Advert
      end
      class SuperFancyAdvert < FancyAdvert
      end

      expect(Generators::DeclareSchema::Migration::Migrator.run.first).to be_present

      up, _ = Generators::DeclareSchema::Migration::Migrator.run do |migrations|
        expect(migrations).to(
          migrate_up(<<~EOS.strip)
            add_column :adverts, :type, :string, limit: 250, null: true#{charset_and_collation}
            add_index :adverts, [:type], name: :on_type
          EOS
          .and migrate_down(<<~EOS.strip)
              remove_index :adverts, name: :on_type
              remove_column :adverts, :type
          EOS
        )
      end

      Advert.field_specs.delete(:type)
      nuke_model_class(SuperFancyAdvert)
      nuke_model_class(FancyAdvert)
      Advert.index_definitions.delete_if { |spec| spec.fields == ["type"] }

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
        declare_schema do
          string :name, default: "No Name", limit: 250, null: true
          text :body, null: true
        end
      end

      expect(Generators::DeclareSchema::Migration::Migrator.run(adverts: { title: :name })).to(
        migrate_up(<<~EOS.strip)
          rename_column :adverts, :title, :name
          change_column :adverts, :name, :string, limit: 250, null: true, default: "No Name"#{charset_and_collation}
        EOS
        .and migrate_down(<<~EOS.strip)
            change_column :adverts, :name, :string, limit: 250, null: true, default: "Untitled"#{charset_and_collation}
            rename_column :adverts, :name, :title
        EOS
      )

      ### Rename a table and add a column

      nuke_model_class(Advert)
      class Ad < ActiveRecord::Base
        declare_schema do
          string   :title, default: "Untitled", limit: 250
          text     :body, null: true
          datetime :created_at
        end
      end

      expect(Generators::DeclareSchema::Migration::Migrator.run(adverts: :ads)).to(
        migrate_up(<<~EOS.strip)
          rename_table :adverts, :ads
          add_column :ads, :created_at, :datetime, null: false
          change_column :ads, :title, :string, limit: 250, null: false, default: \"Untitled\"#{charset_and_collation}
        EOS
      )

      class Advert < ActiveRecord::Base
        declare_schema do
          text :body, null: true
          string :title, default: "Untitled", limit: 250, null: true
        end
      end

      ## Legacy Keys

      # DeclareSchema has some support for legacy keys.

      nuke_model_class(Ad)

      class Advert < ActiveRecord::Base
        declare_schema do
          text :body, null: true
        end
        self.primary_key = "advert_id"
      end

      expect(Generators::DeclareSchema::Migration::Migrator.run(adverts: { id: :advert_id })).to(
        migrate_up(<<~EOS.strip)
          rename_column :adverts, :id, :advert_id
        EOS
      )

      nuke_model_class(Advert)
      ActiveRecord::Base.connection.execute("drop table `adverts`;")

      ## DSL

      # The DSL allows lambdas and constants

      class User < ActiveRecord::Base
        declare_schema do
          string :company, limit: 250, ruby_default: -> { "BigCorp" }
        end
      end
      expect(User.field_specs.keys).to eq(['company'])
      expect(User.field_specs['company'].options[:ruby_default]&.call).to eq("BigCorp")

      nuke_model_class(User)

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
        declare_schema do
          string :company, limit: 250, index: true, unique: true, validates: { presence: true, uniqueness: { case_sensitive: false } }
        end
        self.primary_key = "advert_id"
      end
      up, _down = Generators::DeclareSchema::Migration::Migrator.run
      ActiveRecord::Migration.class_eval(up)
      expect(Ad.field_specs['company'].options[:validates].inspect).to eq("{:presence=>true, :uniqueness=>{:case_sensitive=>false}}")

      # DeclareSchema supports has_and_belongs_to_many relationships and generates the intersection ("join") table
      # with appropriate primary key, indexes, and foreign keys.

      class Advertiser < ActiveRecord::Base
        declare_schema do
          string :name, limit: 250
        end
        has_and_belongs_to_many :creatives
      end
      class Creative < ActiveRecord::Base
        declare_schema do
          string :url, limit: 500
        end
        has_and_belongs_to_many :advertisers
      end

      expect(Generators::DeclareSchema::Migration::Migrator.run).to(
        migrate_up(<<~EOS.strip)
          create_table :advertisers, id: :bigint#{create_table_charset_and_collation} do |t|
            t.string :name, limit: 250, null: false#{charset_and_collation}
          end
          create_table :advertisers_creatives, primary_key: [:advertiser_id, :creative_id]#{create_table_charset_and_collation} do |t|
            t.integer :advertiser_id, limit: 8, null: false
            t.integer :creative_id, limit: 8, null: false
          end
          create_table :creatives, id: :bigint#{create_table_charset_and_collation} do |t|
            t.string :url, limit: 500, null: false#{charset_and_collation}
          end
          add_index :advertisers_creatives, [:creative_id], name: :index_advertisers_creatives_on_creative_id
          add_foreign_key :advertisers_creatives, :advertisers, column: :advertiser_id, name: :advertisers_creatives_FK1
          add_foreign_key :advertisers_creatives, :creatives, column: :creative_id, name: :advertisers_creatives_FK2
      EOS
      )

      nuke_model_class(Ad)
      nuke_model_class(Advertiser)
      nuke_model_class(Creative)
    end

    context 'models with the same parent foreign key relation' do
      before do
        class Category < ActiveRecord::Base
          declare_schema do
            string :name, limit: 250, null: true
          end
        end
        class Advertiser < ActiveRecord::Base
          declare_schema do
            string :name, limit: 250, null: true
          end
          belongs_to :category, limit: 8
        end
        class Affiliate < ActiveRecord::Base
          declare_schema do
            string :name, limit: 250, null: true
          end
          belongs_to :category, limit: 8
        end
      end

      it 'will generate unique constraint names' do
        expect(Generators::DeclareSchema::Migration::Migrator.run).to(
          migrate_up(<<~EOS.strip)
            create_table :categories, id: :bigint, options: "CHARACTER SET utf8mb4 COLLATE utf8mb4_bin" do |t|
              t.string :name, limit: 250, null: true, charset: "utf8mb4", collation: "utf8mb4_bin"
            end
            create_table :advertisers, id: :bigint, options: "CHARACTER SET utf8mb4 COLLATE utf8mb4_bin" do |t|
              t.string  :name, limit: 250, null: true, charset: "utf8mb4", collation: "utf8mb4_bin"
              t.integer :category_id, limit: 8, null: false
            end
            create_table :affiliates, id: :bigint, options: "CHARACTER SET utf8mb4 COLLATE utf8mb4_bin" do |t|
              t.string  :name, limit: 250, null: true, charset: "utf8mb4", collation: "utf8mb4_bin"
              t.integer :category_id, limit: 8, null: false
            end
            add_index :advertisers, [:category_id], name: :index_advertisers_on_category_id
            add_index :affiliates, [:category_id], name: :index_affiliates_on_category_id
            add_foreign_key :advertisers, :categories, column: :category_id, name: :index_advertisers_on_category_id
            add_foreign_key :affiliates, :categories, column: :category_id, name: :index_affiliates_on_category_id
        EOS
        )
        migrate

        nuke_model_class(Advertiser)
        nuke_model_class(Affiliate)
      end
    end if !defined?(SQLite3)

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
            declare_schema do
              text :allow_list, limit: 0xFFFF, serialize: true
            end
          end

          expect(Ad.serialize_args).to eq([[:allow_list]])
        end

        it 'converts defaults with .to_yaml' do
          class Ad < ActiveRecord::Base
            declare_schema do
              string :allow_list, limit: 250, serialize: true, null: true, default: []
              string :allow_hash, limit: 250, serialize: true, null: true, default: {}
              string :allow_string, limit: 250, serialize: true, null: true, default: ['abc']
              string :allow_null, limit: 250, serialize: true, null: true, default: nil
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
            declare_schema do
              string :allow_list, limit: 250, serialize: Array, null: true
            end
          end

          expect(Ad.serialize_args).to eq([[:allow_list, Array]])
        end

        it 'allows Array defaults' do
          class Ad < ActiveRecord::Base
            declare_schema do
              string :allow_list, limit: 250, serialize: Array, null: true, default: [2]
              string :allow_string, limit: 250, serialize: Array, null: true, default: ['abc']
              string :allow_empty, limit: 250, serialize: Array, null: true, default: []
              string :allow_null, limit: 250, serialize: Array, null: true, default: nil
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
            declare_schema do
              string :allow_list, limit: 250, serialize: Hash, null: true
            end
          end

          expect(Ad.serialize_args).to eq([[:allow_list, Hash]])
        end

        it 'allows Hash defaults' do
          class Ad < ActiveRecord::Base
            declare_schema do
              string :allow_loc, limit: 250, serialize: Hash, null: true, default: { 'state' => 'CA' }
              string :allow_hash, limit: 250, serialize: Hash, null: true, default: {}
              string :allow_null, limit: 250, serialize: Hash, null: true, default: nil
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
            declare_schema do
              string :allow_list, limit: 250, serialize: JSON
            end
          end

          expect(Ad.serialize_args).to eq([[:allow_list, JSON]])
        end

        it 'allows JSON defaults' do
          class Ad < ActiveRecord::Base
            declare_schema do
              string :allow_hash, limit: 250, serialize: JSON, null: true, default: { 'state' => 'CA' }
              string :allow_empty_array, limit: 250, serialize: JSON, null: true, default: []
              string :allow_empty_hash, limit: 250, serialize: JSON, null: true, default: {}
              string :allow_null, limit: 250, serialize: JSON, null: true, default: nil
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
            declare_schema do
              string :allow_list, limit: 250, serialize: ValueClass
            end
          end

          expect(Ad.serialize_args).to eq([[:allow_list, ValueClass]])
        end

        it 'allows ValueClass defaults' do
          class Ad < ActiveRecord::Base
            declare_schema do
              string :allow_hash, limit: 250, serialize: ValueClass, null: true, default: ValueClass.new([2])
              string :allow_empty_array, limit: 250, serialize: ValueClass, null: true, default: ValueClass.new([])
              string :allow_null, limit: 250, serialize: ValueClass, null: true, default: nil
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
            declare_schema do
              integer :allow_list, limit: 8, serialize: true
            end
          end
        end.to raise_exception(ArgumentError, /must be :string or :text/)
      end
    end

    context "for Rails #{ActiveSupport::VERSION::MAJOR}" do
      let(:optional_true) { { optional: true } }
      let(:optional_false) { { optional: false } }
      let(:optional_flag) { { false => optional_false, true => optional_true } }

      describe 'belongs_to' do
        context 'with AdCategory and Advert in DB' do
          before do
            unless defined?(AdCategory)
              class AdCategory < ActiveRecord::Base
                declare_schema { }
              end
            end

            class Advert < ActiveRecord::Base
              declare_schema do
                string :name, limit: 250, null: true
                integer :category_id, limit: 8
                integer :nullable_category_id, limit: 8, null: true
              end
            end
            up = Generators::DeclareSchema::Migration::Migrator.run.first
            ActiveRecord::Migration.class_eval(up)
          end

          it 'passes through optional: when given' do
            class AdvertBelongsTo < ActiveRecord::Base
              self.table_name = 'adverts'
              declare_schema { }
              reset_column_information
              belongs_to :ad_category, optional: true
            end
            expect(AdvertBelongsTo.reflections['ad_category'].options).to eq(optional_true)
          end

          describe 'contradictory settings' do # contradictory settings are ok--for example, during migration
            it 'passes through optional: true, null: false' do
              class AdvertBelongsTo < ActiveRecord::Base
                self.table_name = 'adverts'
                declare_schema { }
                reset_column_information
                belongs_to :ad_category, optional: true, null: false
              end
              expect(AdvertBelongsTo.reflections['ad_category'].options).to eq(optional_true)
              expect(AdvertBelongsTo.field_specs['ad_category_id'].options&.[](:null)).to eq(false)
            end

            it 'passes through optional: false, null: true' do
              class AdvertBelongsTo < ActiveRecord::Base
                self.table_name = 'adverts'
                declare_schema { }
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
                    declare_schema { }
                    belongs_to :ad_category, null: #{nullable}
                  end
                EOS
                expect(AdvertBelongsTo.reflections['ad_category'].options).to eq(optional_flag[nullable])
                expect(AdvertBelongsTo.field_specs['ad_category_id'].options&.[](:null)).to eq(nullable)
              end

              it 'infers null: from optional:' do
                eval <<~EOS
                  class AdvertBelongsTo < ActiveRecord::Base
                    declare_schema { }
                    belongs_to :ad_category, optional: #{nullable}
                  end
                EOS
                expect(AdvertBelongsTo.reflections['ad_category'].options).to eq(optional_flag[nullable])
                expect(AdvertBelongsTo.field_specs['ad_category_id'].options&.[](:null)).to eq(nullable)
              end
            end
          end

          it 'deprecates limit:' do
            expect(ActiveSupport::Deprecation).to receive(:warn).with("belongs_to limit: is deprecated since it is now inferred")
            eval <<~EOS
              class UsingLimit < ActiveRecord::Base
                declare_schema { }
                belongs_to :ad_category, limit: 4
              end
            EOS
          end
        end

        context 'when parent object PKs have different limits' do
          before do
            class IdDefault < ActiveRecord::Base
              declare_schema { }
            end
            class Id4 < ActiveRecord::Base
              declare_schema id: :integer do
              end
            end
            class Id8 < ActiveRecord::Base
              declare_schema id: :bigint do
              end
            end
            class Fk < ActiveRecord::Base
              declare_schema { }
              belongs_to :id_default
              belongs_to :id4
              belongs_to :id8
            end
          end

          it 'creates the proper PKs' do
            up = Generators::DeclareSchema::Migration::Migrator.run.first

            create_id4_defaults = up.split("\n").grep(/create_table :id_defaults/).first
            expect(create_id4_defaults).to be, up
            expect(create_id4_defaults).to match(/, id: :bigint/)

            create_id4s = up.split("\n").grep(/create_table :id4s/).first
            expect(create_id4s).to be, up
            expect(create_id4s).to match(/, id: :integer/)

            create_id8s = up.split("\n").grep(/create_table :id8s/).first
            expect(create_id8s).to be, up
            expect(create_id8s).to match(/, id: :bigint/)
          end

          it 'infers the correct FK type from the create_table id: type' do
            up = Generators::DeclareSchema::Migration::Migrator.run.first

            create_fks = up.split("\n").grep(/t\.integer /).map { |command| command.gsub(', null: false', '').gsub(/^ +/, '') }
            if defined?(SQLite3)
              create_fks.map! { |command| command.gsub(/limit: [a-z0-9]+/, 'limit: X') }
              expect(create_fks).to eq([
                                         't.integer :id_default_id, limit: X',
                                         't.integer :id4_id, limit: X',
                                         't.integer :id8_id, limit: X'
                                       ]), up
            else
              expect(create_fks).to eq([
                                         't.integer :id_default_id, limit: 8',
                                         't.integer :id4_id, limit: 4',
                                         't.integer :id8_id, limit: 8'
                                       ]), up
            end
          end

          context "when parent objects were migrated before and later definitions don't have explicit id:" do
            before do
              up = Generators::DeclareSchema::Migration::Migrator.run.first
              ActiveRecord::Migration.class_eval up
              nuke_model_class(IdDefault)
              nuke_model_class(Id4)
              nuke_model_class(Id8)
              nuke_model_class(Fk)
              ActiveRecord::Base.connection.schema_cache.clear!


              class NewIdDefault < ActiveRecord::Base
                self.table_name = 'id_defaults'
                declare_schema { }
              end
              class NewId4 < ActiveRecord::Base
                self.table_name = 'id4s'
                declare_schema { }
              end
              class NewId8 < ActiveRecord::Base
                self.table_name = 'id8s'
                declare_schema { }
              end
              class NewFk < ActiveRecord::Base
                declare_schema { }
                belongs_to :new_id_default
                belongs_to :new_id4
                belongs_to :new_id8
              end
            end

            it 'infers the correct FK :integer limit: ' do
              up = Generators::DeclareSchema::Migration::Migrator.run.first

              create_fks = up.split("\n").grep(/t\.integer /).map { |command| command.gsub(', null: false', '').gsub(/^ +/, '') }
              if defined?(SQLite3)
                create_fks.map! { |command| command.gsub(/limit: [a-z0-9]+/, 'limit: X') }
                expect(create_fks).to eq([
                                           't.integer :new_id_default_id, limit: X',
                                           't.integer :new_id4_id, limit: X',
                                           't.integer :new_id8_id, limit: X'
                                         ]), up
              else
                expect(create_fks).to eq([
                                           't.integer :new_id_default_id, limit: 8',
                                           't.integer :new_id4_id, limit: 4',
                                           't.integer :new_id8_id, limit: 8'
                                         ]), up
              end
            end
          end
        end
      end
    end

    describe 'migration base class' do
      it 'adapts to Rails 4' do
        class Advert < active_record_base_class.constantize
          declare_schema do
            string :title, limit: 100
          end
        end

        generate_migrations '-n', '-m'

        migrations = Dir.glob('db/migrate/*declare_schema_migration*.rb')
        expect(migrations.size).to eq(1), migrations.inspect

        migration_content = File.read(migrations.first)
        first_line = migration_content.split("\n").first
        base_class = first_line.split(' < ').last
        expect(base_class).to eq("ActiveRecord::Migration[4.2]")
      end
    end

    context 'Does not generate migrations' do
      it 'for aliased fields bigint -> integer limit 8' do
        class Advert < active_record_base_class.constantize
          declare_schema do
            bigint :price
          end
        end

        generate_migrations '-n', '-m'

        migrations = Dir.glob('db/migrate/*declare_schema_migration*.rb')
        expect(migrations.size).to eq(1), migrations.inspect

        class Advert < active_record_base_class.constantize
          declare_schema do
            integer :price, limit: 8
          end
        end

        expect { generate_migrations '-n', '-g' }.to output("Database and models match -- nothing to change\n").to_stdout
      end
    end

    context 'default_schema' do
      let(:default_schema_block) { nil }
      let(:declare_model) do
        -> do
          class Advert < active_record_base_class.constantize
            declare_schema do
              integer :price, limit: 8
            end
          end
        end
      end

      before do
        DeclareSchema.default_schema(&default_schema_block)
      end

      after do
        DeclareSchema.clear_default_schema
      end

      context 'when unset' do
        it 'adds nothing' do
          declare_model.call

          expect(Advert.field_specs.keys).to eq(['price'])
        end
      end

      context 'when set to a block' do
        let(:default_schema_block) do
          -> do
            timestamps
            field :lock_version, :integer, default: 1
          end
        end

        it 'adds the fields in that block' do
          declare_model.call

          expect(Advert.field_specs.keys).to eq(['price', 'created_at', 'updated_at', 'lock_version'])
        end

        context 'and the model sets default_schema: false' do
          before do
            class Advert < active_record_base_class.constantize
              declare_schema default_schema: false do
                integer :price, limit: 8
              end
            end
          end

          it 'does not add the default schema fields' do
            expect(Advert.field_specs.keys).to eq(['price'])
          end
        end

        context 'and the block has redundant fields' do
          before do
            class Advert < active_record_base_class.constantize
              declare_schema do
                integer :price, limit: 8
                timestamps
              end
            end
          end

          it 'is a no-op' do
            expect(Advert.field_specs.keys).to eq(['price', 'created_at', 'updated_at', 'lock_version'])
          end
        end
      end
    end
  end
end
