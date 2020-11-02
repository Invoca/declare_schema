# DeclareSchema

Declare your Rails/active_record model schemas and have database migrations generated for you!

## Example

Make a model and declare your schema within a `fields do ... end` block:
```ruby
class Company < ActiveRecord::Base
  fields do
    company_name :string, limit: 100
    ticker_symbol :string, limit: 4, null: true, index: true, unique: true
    employee_count :integer
    comments :text

    timestamps
  end

  belongs_to :industry
end
```
Then generate the migration:
```sh
$ rails generate declare_schema:migration

---------- Up Migration ----------
create_table :companies, id: :bigint do |t|
  t.string   :company_name, null: false, limit: 100
  t.string   :ticker_symbol, limit: 4
  t.integer  :employee_count, null: false
  t.text     :comments, null: false
  t.datetime :created_at
  t.datetime :updated_at
  t.integer  :industry_id, null: false
end
add_index :companies, [:ticker_symbol], unique: true, name: 'on_ticker_symbol'
add_index :companies, [:industry_id], name: 'on_industry_id'
execute "ALTER TABLE companies ADD CONSTRAINT index_companies_on_industry_id FOREIGN KEY index_companies_on_industry_id(industry_id) REFERENCES industries(id) "
----------------------------------

---------- Down Migration --------
drop_table :companies
----------------------------------


What now: [g]enerate migration, generate and [m]igrate now or [c]ancel?  g
  => "g"

Migration filename: [<enter>=declare_schema_migration_1|<custom_name>]: add_company_model
```
Note that the migration generator is interactive -- it can't tell the difference between renaming something vs. adding one thing and removing another, so sometimes it will ask you to clarify.

## Migrator Configuration

The following configuration options are available for the gem and can be used
during the initialization of your Rails application.

### after_load_rails_models callback

During the initializtion process for generating migrations, `DeclareSchema` will
trigger the `eager_load!` on the `Rails` application and all `Rails::Engine`s loaded
into scope.  If you need to generate migrations for models that aren't automatically loaded by `eager_load!`,
load them in the `after_load_rails_models` block.

**Example Configuration**

```ruby
DeclareSchema::Migration::Migrator.after_load_rails_models do
  require 'lib/some/hidden/models.rb'
end
```

## Installing

Install the `DeclareSchema` gem directly:
```
  $ gem install declare_schema
```
or add it to your `bundler` Gemfile:
```
  gem 'declare_schema'
```
## Testing
To run tests:
```
rake test:prepare_testapp[force]
rake test:all < test_responses.txt
```
