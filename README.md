# DeclareSchema

Declare your Rails/ActiveRecord model schemas and have database migrations generated for you!

## Example

Make a model and declare your schema within a `declare_schema do ... end` block:
```ruby
class Company < ActiveRecord::Base
  declare_schema do
    string  :company_name,  limit: 100
    string  :ticker_symbol, limit: 4, null: true, index: { unique: true }
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

## declare_schema DSL field (column) declaration
The `declare_schema` DSL is yielded to the block as shown with block variable `t` (for table).
Each field (column) is declared with the syntax `t.<type> :<column_name>, <options>` as shown here for the `string` column `company_name`:
```ruby
create_table :companies, id: :bigint do |t|
  t.string   :company_name, null: false, limit: 100
    ...
end
```
### Field (Column) Types
All of the ActiveRecord field types are supported, as returned by the database driver in use at the time.
These typically include:
- `binary` (blob)
- `text`
- `integer`
- `bigint`
- `float`
- `decimal`
- `date`
- `time`
- `datetime`
- `timestamp`
- `string` (varchar)
- `boolean` (tinyint 0 or 1)
- `json`
- `array`
- `enum` (if using the `activerecord-mysql-enum` gem) (MySQL enum)

### Field (Column) Options
The following field options are:
- `limit` (integer) - The maximum length of the field. For `text` and `binary` fields, this is the maximum number of bytes.
 For `string` fields, this is the maximum number of characters, and defaults to `DeclareSchema.default_string_limit`; for `text`, defaults to `DeclareSchema.default_text_limit`.
 For `enum`
- `null` (boolean) - Whether the field is nullable. Defaults to `DeclareSchema.default_null`.
- `default` (any) - The default value for the field.
- `ruby_default` (Proc) - A callable Ruby Proc that returns the default value for the field. This is useful for default values that require Ruby computation.
  (Provided by the `attr_default` gem.)
- `index` (boolean [deprecated] or hash) - Whether to create an index for the field. If `true`, defaults to `{ unique: false }` [deprecated]. See below for supported `index` options.
- `unique` [deprecated] (boolean) - Whether to create a unique index for the field. Defaults to `false`. Deprecated in favor of `index: { unique: <boolean> }`.
- `charset` (string) - The character set for the field. Defaults to `default_charset` (see below).
- `collation` (string) - The collation for the field. Defaults to `default_collation` (see below).
- `precision` (integer) - The precision for the numeric field.
- `scale` (integer) - The scale for the numeric field.

### Index Options
The following `index` options are supported:
- `name` (string) - The name of the index. Defaults the longest format that will fit within `DeclareSchema.max_index_and_constraint_name_length`. They are tried in this order:
1. `index_<table>_on_<col1>[_and_<col2>...]>`.
2. `__<col1>[_<col2>...]>`
3. `<table_prefix><sha256_of_columns_prefix>`
- `unique` (boolean) - Whether the index is unique. Defaults to `false`.
- `order` (synbol or hash) - The index order. If `:asc` or `:desc` is provided, it is used as the order for all columns. If hash is provided, it is used to specify the order of individual columns, where the column names are given as `Symbol` hash keys with values of `:asc` or `:desc` indicating the sort order of that column.
- `length` (integer or hash) - The partial index length(s). If an integer is provided, it is used as the length for all columns. If a hash is provided, it is used to specify the length for individual columns, where the column names are given as `Symbol` hash keys.
- `where` (string) - The subset index predicate.

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
Configurations can be set globally to customize default declaration for the following values:

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
Note: MySQL 8+ aliases charset 'utf8' to 'utf8mb3', and 'utf8_general_ci' to 'utf8mb3_unicode_ci',
so when running on MySQL 8+, those aliases will be applied by `DeclareSchema`.

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
