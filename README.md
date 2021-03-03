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

### before_generating_migration callback

During the initializtion process for generating migrations, `DeclareSchema` will
trigger the `eager_load!` on the `Rails` application and all `Rails::Engine`s loaded
into scope.  If you need to generate migrations for models that aren't automatically loaded by `eager_load!`,
load them in the `before_generating_migration` block.

**Example Configuration**

```ruby
DeclareSchema::Migration::Migrator.before_generating_migration do
  require 'lib/some/hidden/models.rb'
end
```

## Declaring Character Set and Collation
_Note: This feature currently only works for MySQL database configurations._

MySQL originally supported UTF-8 in the range of 1-3 bytes (`mb3` or "multi-byte 3")
which covered the full set of Unicode code points at the time: U+0000 - U+FFFF.
But later, Unicode was extended beyond U+FFFF to make room for emojis, and with that
UTF-8 require 1-4 bytes (`mb4` or "multi-byte 4"). With this addition, there has
come a need to dynamically define the character set and collation for individual
tables and columns in the database. With `declare_schema` this can be configured
at three separate levels

### Global Configuration
The character set and collation for all tables and fields can be set at the global level
using the `Generators::DeclareSchema::Migrator.default_charset=` and
`Generators::DeclareSchema::Migrator.default_collation=` configuration methods.

For example, adding the following to your `config/initializers` directory will
turn all tables into `utf8mb4` supporting tables:

**declare_schema.rb**
```ruby
# frozen_string_literal: true

Generators::DeclareSchema::Migration::Migrator.default_charset   = "utf8mb4"
Generators::DeclareSchema::Migration::Migrator.default_collation = "utf8mb4_bin"
```

### Table Configuration
In order to configure a table's default character set and collation, the `charset` and
`collation` arguments can be added to the `fields` block.

For example, if you have a comments model that needs `utf8mb4` support, it would look
like the following:

**app/models/comment.rb**
```ruby
# frozen_string_literal: true

class Comment < ActiveRecord::Base
  fields charset: "utf8mb4", collation: "utf8mb4_bin" do
    subject :string, limit: 255
    content :text,   limit: 0xffff_ffff
  end
end
```

### Field Configuration
If you're looking to only change the character set and collation for a single field
in the table, simply set the `charset` and `collation` configuration options on the
field definition itself.

For example, if you only want to support `utf8mb4` for the content of a comment, it would
look like the following:

**app/models/comment.rb**
```ruby
# frozen_string_literal: true

class Comment < ActiveRecord::Base
  fields do
    subject :string, limit: 255
    context :text,   limit: 0xffff_ffff, charset: "utf8mb4", collation: "utf8mb4_bin"
  end
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
rake test:all
```
