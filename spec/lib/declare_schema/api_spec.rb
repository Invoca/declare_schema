# frozen_string_literal: true

require 'rails'
require 'rails/generators'

RSpec.describe 'DeclareSchema API' do
  before do
    load File.expand_path('prepare_testapp.rb', __dir__)
  end

  context 'Using fields' do
    describe 'example models' do
      it 'generates a model' do
        generate_model 'advert', 'title:string', 'body:text'

        # The above will generate the test, fixture and a model file like this:
        # model_declaration = Rails::Generators.invoke('declare_schema:model', ['advert2', 'title:string', 'body:text'])
        # expect(model_declaration.first).to eq([["Advert"], nil, "app/models/advert.rb", nil,
        #                                       [["AdvertTest"], "test/models/advert_test.rb", nil, "test/fixtures/adverts.yml"]])

        expect_model_definition_to_eq('advert', <<~EOS)
          class Advert < #{active_record_base_class}
  
            fields do
              title :string, limit: 255
              body  :text
            end
  
          end
        EOS

        clean_up_model('advert2')

        # The migration generator uses this information to create a migration.
        # The following creates and runs the migration:

        expect(system("bundle exec rails generate declare_schema:migration -n -m")).to be_truthy

        # We're now ready to start demonstrating the API

        load_models

        if Rails::VERSION::MAJOR == 5
          # TODO: get this to work on Travis for Rails 6
          generate_migrations '-n', '-m'
        end

        require 'advert'

        ## The Basics

        # The main feature of DeclareSchema, aside from the migration generator, is the ability to declare rich types for your fields. For example, you can declare that a field is an email address, and the field will be automatically validated for correct email address syntax.

        ### Field Types

        # Field values are returned as the type you specify.

        Advert.destroy_all

        a = Advert.new(body: "This is the body", id: 1, title: "title")
        expect(a.body).to eq("This is the body")

        # This also works after a round-trip to the database

        a.save!
        expect(a.reload.body).to eq("This is the body")

        ## Names vs. Classes

        ## Model extensions

        # DeclareSchema adds a few features to your models.

        ### `Model.attr_type`

        # Returns the type (i.e. class) declared for a given field or attribute

        Advert.connection.schema_cache.clear!
        Advert.reset_column_information

        expect(Advert.attr_type(:title)).to eq(String)
        expect(Advert.attr_type(:body)).to eq(String)

        ## Field validations

        # DeclareSchema gives you some shorthands for declaring some common validations right in the field declaration

        ### Required fields

        # The `:required` argument to a field gives a `validates_presence_of`:

        class AdvertWithRequiredTitle < ActiveRecord::Base
          self.table_name = 'adverts'

          fields do
            title :string, :required, limit: 255
          end
        end

        a = AdvertWithRequiredTitle.new
        expect(a.valid? || a.errors.full_messages).to eq(["Title can't be blank"])
        a.id = 2
        a.body = "hello"
        a.title = "Jimbo"
        a.save!

        ### Unique fields

        # The `:unique` argument in a field declaration gives `validates_uniqueness_of`:

        class AdvertWithUniqueTitle < ActiveRecord::Base
          self.table_name = 'adverts'

          fields do
            title :string, :unique, limit: 255
          end
        end

        a = AdvertWithUniqueTitle.new :title => "Jimbo", id: 3, body: "hello"
        expect(a.valid? || a.errors.full_messages).to eq(["Title has already been taken"])
        a.title = "Sambo"
        a.save!
      end
    end
  end

  context 'Using declare_schema' do
    describe 'example models' do
      # TODO: Unskip these tests after updating the generator to use declare_schema
      xit 'generates a model' do
        generate_model 'advert', 'string:title', 'text:body'

        # The above will generate the test, fixture and a model file like this:
        # model_declaration = Rails::Generators.invoke('declare_schema:model', ['advert2', 'title:string', 'body:text'])
        # expect(model_declaration.first).to eq([["Advert"], nil, "app/models/advert.rb", nil,
        #                                       [["AdvertTest"], "test/models/advert_test.rb", nil, "test/fixtures/adverts.yml"]])

        expect_model_definition_to_eq('advert', <<~EOS)
          class Advert < #{active_record_base_class}

            declare_schema do
              string :title, limit: 255
              text   :body
            end

          end
        EOS

        clean_up_model('advert2')

        # The migration generator uses this information to create a migration.
        # The following creates and runs the migration:

        expect(system("bundle exec rails generate declare_schema:migration -n -m")).to be_truthy

        # We're now ready to start demonstrating the API

        load_models

        if Rails::VERSION::MAJOR == 5
          # TODO: get this to work on Travis for Rails 6
          generate_migrations '-n', '-m'
        end

        require 'advert'

        ## The Basics

        # The main feature of DeclareSchema, aside from the migration generator, is the ability to declare rich types for your fields. For example, you can declare that a field is an email address, and the field will be automatically validated for correct email address syntax.

        ### Field Types

        # Field values are returned as the type you specify.

        Advert.destroy_all

        a = Advert.new(body: "This is the body", id: 1, title: "title")
        expect(a.body).to eq("This is the body")

        # This also works after a round-trip to the database

        a.save!
        expect(a.reload.body).to eq("This is the body")

        ## Names vs. Classes

        ## Model extensions

        # DeclareSchema adds a few features to your models.

        ### `Model.attr_type`

        # Returns the type (i.e. class) declared for a given field or attribute

        Advert.connection.schema_cache.clear!
        Advert.reset_column_information

        expect(Advert.attr_type(:title)).to eq(String)
        expect(Advert.attr_type(:body)).to eq(String)

        ## Field validations

        # DeclareSchema gives you some shorthands for declaring some common validations right in the field declaration

        ### Required fields

        # The `:required` argument to a field gives a `validates_presence_of`:

        class AdvertWithRequiredTitle < ActiveRecord::Base
          self.table_name = 'adverts'

          declare_schema do
            string :title, :required, limit: 255
          end
        end

        a = AdvertWithRequiredTitle.new
        expect(a.valid? || a.errors.full_messages).to eq(["Title can't be blank"])
        a.id = 2
        a.body = "hello"
        a.title = "Jimbo"
        a.save!

        ### Unique fields

        # The `:unique` argument in a field declaration gives `validates_uniqueness_of`:

        class AdvertWithUniqueTitle < ActiveRecord::Base
          self.table_name = 'adverts'

          declare_schema do
            string :title, :unique, limit: 255
          end
        end

        a = AdvertWithUniqueTitle.new :title => "Jimbo", id: 3, body: "hello"
        expect(a.valid? || a.errors.full_messages).to eq(["Title has already been taken"])
        a.title = "Sambo"
        a.save!
      end
    end
  end
end
