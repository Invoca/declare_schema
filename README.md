# DeclareSchema

Declare your Rails/ActiveRecord model schemas and have database migrations generated for you!

## Example

Make a model and declare your schema within a `declare_schema do ... end` block:
```ruby
class Company < ActiveRecord::Base
  declare_schema do
    string  :company_name,  limit: 100
    string  :ticker_symbol, limit: 4, null: true, index: true, unique: true
    integer :employee_count
    text    :comments

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

## declare_schema macro options

Any options provided to the `declare_schema` macro will be passed on to `create_table`. For example, to set the `id` column of the table explicitly to `:bigint`:
```
declare_schema id: :bigint do
  string  :company_name,  limit: 100
  ...
end
```

## Usage without Rails

When using `DeclareSchema` without Rails, you can use the `declare_schema/rake` task to generate the migration file.

To do so, add the following require to your Rakefile:
```ruby
require 'declare_schema/rake'
```

Then, run the task:
```sh
rake declare_schema:generate
```

## Migrator Configuration

The following configuration options are available for the gem and can be used
during the initialization of your Rails application.

### before_generating_migration callback

During the initialization process for generating migrations, `DeclareSchema` will
trigger the `eager_load!` on the `Rails` application and all `Rails::Engine`s loaded
into scope.  If you need to generate migrations for models that aren't automatically loaded by `eager_load!`,
load them in the `before_generating_migration` block.

For example:

```ruby
DeclareSchema::Migration::Migrator.before_generating_migration do
  require 'lib/some/hidden/models.rb'
end
```

### default_schema
If there are default columns you would like in the schema for every model, you can define them in a block that is registered with
`DeclareSchema.default_schema`. For example:

```ruby
DeclareSchema.default_schema do
  timestamps
  optimistic_lock
end
```
This will add these fields to the schema of each model (if not already there).
If you have a model where you don't want the defaults applied, that can be set with the `default_schema:` boolean option to `declare_schema` (the default value is true). For example:
```ruby
class User < ActiveRecord::Base
  declare_schema default_schema: false do
    ...
  end
end
```

### clear_default_schema
This method clears out any previously declared `default_schema`. This can be useful for tests.
```ruby
DeclareSchema.clear_default_schema
```

### Global Configuration
Configurations can be set at globally to customize default declaration for the following values:

#### Text Limit
The default text limit can be set using the `DeclareSchema.default_text_limit=` method.
Note that a `nil` default means that there is no default-- so every declaration must be explicit.
This will `raise` a `limit: must be provided for field :text...` error when the default value is `nil` and there is no explicit
declaration.

For example, adding the following to your `config/initializers` directory will
set the default `text limit` value to `0xffff`:

**declare_schema.rb**
```ruby
DeclareSchema.default_text_limit = 0xffff
```

#### String Limit
The default string limit can be set using the `DeclareSchema.default_string_limit=` method.
Note that a `nil` default means that there is no default-- so every declaration must be explicit.
This will `raise` a `limit: must be provided for field :string...` error when the default value is `nil` and there is no explicit
declaration.

For example, adding the following to your `config/initializers` directory will
set the default `string limit` value to `255`:

**declare_schema.rb**
```ruby
DeclareSchema.default_string_limit = 255
```

#### Null
The default null value can be set using the `DeclareSchema.default_null=` method.
Note that a `nil` default means that there is no default-- so every declaration must be explicit.
This will `raise` a `null: must be provided for field...` error when the default value is `nil` and there is no explicit
declaration.

For example, adding the following to your `config/initializers` directory will
set the default `null` value to `true`:

**declare_schema.rb**
```ruby
DeclareSchema.default_null = true
```

#### Generate Foreign Keys
You can choose whether to generate foreign keys by using the `DeclareSchema.default_generate_foreign_keys=` method.
This defaults to `true` and can only be set globally.

For example, adding the following to your `config/initializers` directory will cause
foreign keys not to be generated:

**declare_schema.rb**
```ruby
DeclareSchema.default_generate_foreign_keys = false
```

#### Generate Indexing
You can choose whether to generate indexes automatically by using the `DeclareSchema.default_generate_indexing=` method.
This defaults to `true` and can only be set globally.

For example, adding the following to your `config/initializers` directory will cause
indexes not to be generated by `declare_schema`:

**declare_schema.rb**
```ruby
DeclareSchema.default_generate_indexing = false
```
#### Character Set and Collation
The character set and collation for all tables and fields can be set at globally
using the `Generators::DeclareSchema::Migrator.default_charset=` and
`Generators::DeclareSchema::Migrator.default_collation=` configuration methods.

For example, adding the following to your `config/initializers` directory will
turn all tables into `utf8mb4` supporting tables:

**declare_schema.rb**
```ruby
DeclareSchema.default_charset   = "utf8mb4"
DeclareSchema.default_collation = "utf8mb4_bin"
```
#### db:migrate Command
`declare_schema` can run the migration once it is generated, if the `--migrate` option is passed.
If not, it will display the command to run later. By default this command is
```
bundle exec rails db:migrate
```
If your repo has a different command to run for migrations, you can configure it like this:
```ruby
DeclareSchema.db_migrate_command = "bundle exec rails db:migrate_immediate"
```

## The `belongs_to` Association
The foreign key for a `belongs_to` association refers to the primary key of the associated model. The `belongs_to`
association is outside of the `declare_schema do` block, so `declare_schema` intercepts the `belongs_to` macro to
infer the foreign key column.

By default, `declare_schema` creates an index for `belongs_to` relations. If this default index is not desired,
you can use `index: false` in the `belongs_to` expression. This may be the case if, for example, a different index
already covers those columns at the front.

## The `has_and_belongs_to_many` Association
Like the `belongs_to` association, `has_and_belongs_to_many` is outside of the `declare_schema ` block. `declare_schema` similarly
infers foreign keys (and the intersection table).

## Ignored Tables
If a table's schema or metadata are managed elsewhere, `declare_schema` can be instructed to ignore it
by adding those table names to the array assigned to `Generators::DeclareSchema::Migration::Migrator.ignore_tables`.
For example:

```ruby
::Generators::DeclareSchema::Migration::Migrator.ignore_tables = [
  "delayed_jobs",
  "my_snowflake_table",
  ...
]
```

Note: `declare_schema` always ignores these tables:
- The ActiveRecord `schema_info` table
- The ActiveRecord schema migrations table (generally named `schema_migrations`)
- The ActiveRecord internal metadata table (generally named `ar_internal_metadata`)
- If defined/configured, the CGI ActiveRecordStore session table

## Maximum Length of Index and Constraint Names

MySQL limits the length of index and constraint names to 64 characters.
Because the migrations generated by `DecleareSchema` are intended to be portable to any database type that
ActiveRecord supports, `DeclareSchema` will generate names that do not exceed the
configurable value:
```ruby
DeclareSchema.max_index_and_constraint_name_length = 64
```
If you know that your migrations will only be used on a database type with a different limit, you can
adjust this configuration value. A `nil` value means "unlimited".

## Declaring Character Set and Collation
_Note: This feature currently only works for MySQL database configurations._

MySQL originally supported UTF-8 in the range of 1-3 bytes (`mb3` or "multi-byte 3")
which covered the full set of Unicode code points at the time: U+0000 - U+FFFF.
But later, Unicode was extended beyond U+FFFF to make room for emojis, and with that
UTF-8 require 1-4 bytes (`mb4` or "multi-byte 4"). With this addition, there has
come a need to dynamically define the character set and collation for individual
tables and columns in the database. With `declare_schema` this can be configured
at three separate levels.

### Global Configuration
The global configuration option is explained above in the [Character Set and Collation](#Character-Set-and-Collation) section.

### Table Configuration
In order to configure a table's default character set and collation, the `charset` and
`collation` arguments can be added to the `declare_schema` block.

For example, if you have a comments model that needs `utf8mb4` support, it would look
like the following:

**app/models/comment.rb**
```ruby
# frozen_string_literal: true

class Comment < ActiveRecord::Base
  declare_schema charset: "utf8mb4", collation: "utf8mb4_bin" do
    string :subject, limit: 255
    text   :content, limit: 0xffff_ffff
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
  declare_schema do
    string :subject, limit: 255
    text   :context, limit: 0xffff_ffff, charset: "utf8mb4", collation: "utf8mb4_bin"
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
