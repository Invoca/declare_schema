# DeclareSchema API

In order for the API examples to run we need to load the rails generators of our testapp:
{.hidden}

    doctest: prepare testapp environment
    doctest_require: 'prepare_testapp'
{.hidden}

## Example Models

Let's define some example models that we can use to demonstrate the API. With DeclareSchema we can use the 'declare_schema:model' generator like so:

    $ rails generate declare_schema:model advert title:string body:text

This will generate the test, fixture and a model file like this:

    >> Rails::Generators.invoke 'declare_schema:model', %w(advert title:string body:text)
{.hidden}

    class Advert < ActiveRecord::Base
      fields do
        title :string
        body :text, limit: 0xffff, null: true
      end
    end

The migration generator uses this information to create a migration. The following creates and runs the migration so we're ready to go.

    $ rails generate declare_schema:migration -n -m

We're now ready to start demonstrating the API

    >> require_relative "#{Rails.root}/app/models/advert.rb" if Rails::VERSION::MAJOR > 5
    >> Rails::Generators.invoke 'declare_schema:migration', %w(-n -m)
    >> Rails::Generators.invoke 'declare_schema:migration', %w(-n -m)
{.hidden}

## The Basics

The main feature of DeclareSchema, aside from the migration generator, is the ability to declare rich types for your fields. For example, you can declare that a field is an email address, and the field will be automatically validated for correct email address syntax.

### Field Types

Field values are returned as the type you specify.

        >> a = Advert.new :body => "This is the body", id: 1, title: "title"
        >> a.body.class
        => String

This also works after a round-trip to the database

        >> a.save
        >> b = Advert.find(a.id)
        >> b.body.class
        => String

## Names vs. Classes

The full set of available symbolic names is

 * `:integer`
 * `:float`
 * `:decimal`
 * `:string`
 * `:text`
 * `:boolean`
 * `:date`
 * `:datetime`
 * `:html`
 * `:textile`
 * `:markdown`
 * `:password`

You can add your own types too. More on that later.


## Model extensions

DeclareSchema adds a few features to your models.

### `Model.attr_type`

Returns the type (i.e. class) declared for a given field or attribute

        >> Advert.connection.schema_cache.clear!
        >> Advert.reset_column_information
        >> Advert.attr_type :title
        => String
        >> Advert.attr_type :body
        => String

## Field validations

DeclareSchema gives you some shorthands for declaring some common validations right in the field declaration

### Required fields

The `:required` argument to a field gives a `validates_presence_of`:

        >>
         class Advert
           fields do
             title :string, :required, limit: 255
           end
         end
        >> a = Advert.new
        >> a.valid?
        => false
        >> a.errors.full_messages
        => ["Title can't be blank"]
        >> a.id = 2
        >> a.body = "hello"
        >> a.title = "Jimbo"
        >> a.save
        => true


### Unique fields

The `:unique` argument in a field declaration gives `validates_uniqueness_of`:

        >>
         class Advert
           fields do
             title :string, :unique, limit: 255
           end
         end
        >> a = Advert.new :title => "Jimbo", id: 3, body: "hello"
        >> a.valid?
        => false
        >> a.errors.full_messages
        => ["Title has already been taken"]
        >> a.title = "Sambo"
        >> a.save
        => true
