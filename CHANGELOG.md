# CHANGELOG for `declare_schema`

Inspired by [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

Note: this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [2.0.0] - Unreleased
### Added
- Added support for Rails 7.0 and 7.1
- Add support for automatic enum scopes for each value in the `:limit` array
### Removed
- Removed support for Rails < 6.0

## [1.4.0] - 2024-01-24
### Added
- Added support for partial indexes with `length:` option.
### Changed
- Deprecate index: 'name' and unique: true|false in favor of index: { name: 'name', unique: true|false }.

## [1.3.6] - 2024-01-22
### Fixed
- Add missing commits around connection: and Array check for composite declared primary key.

## [1.3.5] - 2024-01-22
### Fixed
- Make `default_charset=` and `default_collation=` lazy so they don't use the database connection to check the
  MySQL version. Instead, that is checked the first time `default_charset` or `default_collation` is called.

## [1.3.4] - 2024-01-18
### Fixed
- Add test for migrating `has_and_belongs_to_many` associations and fix them to properly declare their
  2 foreign keys as the primary key of the join table, rather than just a unique index.

## [1.3.3] - 2024-01-17
### Fixed
- Fix a MySQL 8 bug where MySQL 8+ renames charset 'utf8' to 'utf8mb3' and collation 'utf8_general_ci' to
  'utf8mb3_unicode_ci'.

## [1.3.2] - 2024-01-12
### Fixed
- Fix bug in migrator when table option definitions differ

## [1.3.1] - 2023-10-12
### Fixed
- Fix bug in default index name when table name + __ + column suffix exceeds `DeclareSchema.max_index_and_constraint_name_length`.
  In this case we truncate the table name and append part of its hash.

## [1.3.0] - 2023-07-10
### Added
- Added `DeclareSchema.max_index_and_constraint_name_length` with default of 64.

## [1.2.3] - 2023-04-04
### Changed
- Fixed a bug where renaming a foreign key resulted in an incorrect migration

## [1.2.2] - 2023-01-27
### Changed
- Documented `belongs_to` and `has_and_belongs_to_many` behavior
- Documented configurable ignored tables behavior

### Fixed
- Ruby 3.x kwargs issue when calling `validates`

### Removed
- Ruby 2.5 from test matrix

## [1.2.1] - 2022-09-25
### Fixed
- If Rails is defined, raise if `Rails.application` is `nil`.

## [1.2.0] - 2022-09-14
### Added
- Added a rake task definition that can be optionally included into a non-Rails project to generate
  schema migrations.

### Fixed
- Fixed a bug where not aliasing column names was allowing mysql to return them using their uppercase
  variants

## [1.1.0] - 2022-07-22
### Changed
- Fixed a bug where `DeclareSchema::Model::HabtmModelShim` `indexes` and `integer limits` were not being generated properly. Use `limit 8` for ids and primary composite key for habtm model.
- `index_definitions_with_primary_key`

## [1.0.2] - 2022-07-18
### Fixed
- Fixed a bug where `SchemaChange::ColumnRemove` was not loaded and causing an exception to raise
when a column was being removed during migration generation

## [1.0.1] - 2022-07-12
### Fixed
- Remove lingering usage of `fallback_find_primary_key` method that was removed in `0.14.0`

## [1.0.0] - 2022-03-28
### Added
- Added support for Ruby 3+

### Removed
- Removed deprecated `fields` block declaration

## [0.14.3] - 2021-09-01
### Fixed
- Fixed more Ruby 2.7 warnings about needing `**options` when calling a method that has `**options` in its signature.

## [0.14.2] - 2021-09-01
### Fixed
- Fixed another Ruby 2.7 warning about needing `**options` when calling a method that has `**options` in its signature.

## [0.14.1] - 2021-09-01
### Fixed
- Fixed Ruby 2.7 warning about needing `**options` when calling a method that has `**options` in its signature.

## [0.14.0] - 2021-08-10
### Removed
- Dropped support for Rails versions less than 5.

## [0.13.2] - 2021-08-04
### Fixed
- Fixed issue with disable_auto_increment support for new tables.

## [0.13.1] - 2021-08-02
### Fixed
- Fixed migration file indentation bug in Rails 5 where the first line was indented an extra 4 characters.
 And fixed the longstanding triple-spacing bug to use double spacing.

## [0.13.0] - 2021-06-11
### Added
- Added support for `default_schema` block to apply a default schema to every model, unless disabled for that model with `default_schema: false`.

## [0.12.1] - 2021-05-10
### Fixed
- When an `enum` type field is declared, there is now enforcement that its `limit:` must be an array of 1 or more Symbols,
  and its `default:`--if given--must be a Symbol or `nil`.

## [0.12.0] - 2021-04-28
### Added
- `belongs_to` now always infers the `limit:` of the foreign key to match that of the primary key it points to.
 Note: this isn't possible for polymorphic foreign keys, so it assumes `limit: 8` there...unless the schema
 was migrated in the past with `limit: 4`.

## [0.11.1] - 2021-03-26
### Fixed
- Fixed a bug where up and down in generated migration would be empty in Rails 4.

## [0.11.0] - 2021-03-22
### Removed
- Removed `g|m|c` prompt entirely, since it was confusing. Instead, the migration is
 always generated; the user may press ^C at the filename prompt to cancel.
 The migration will be run if `--migrate` is passed; otherwise, the migrate command will be displayed to be run later.
### Added
- Added the new configuration option `DeclareSchema.@db_migrate_command =`.
### Fixed
- Fixed bug where foreign key constraint names are not globally unique

## [0.10.1] - 2021-03-18
### Fixed
- Migration steps are now generated in a defined dependency order, so that--for example--indexes that depend
 on columns are deleted first, before the columns themselves are deleted (since the latter implicitly does the former, which would break the migration when run).
- Related to the above, down migration steps are now always generated in exactly the reverse order of the up migration steps.

## [0.10.0] - 2021-03-17
### Deprecated
- Deprecated the `fields` DSL method in favor of `declare_schema`.

### Added
- Added the `declare_schema` method to replace `fields`. We now expect a column's type to come before the name
i.e. `declare schema { string :title }`. Otherwise, there is no difference between `fields` and `declare_schema`.

## [0.9.0] - 2021-03-01
### Added
- Added configurable default settings for `default_text_limit`, `default_string_limit`, `default_null`,
`default_generate_foreign_keys` and `default_generate_indexing` to allow developers to adhere to project conventions.

### Changed
- Moved and deprecated default settings for `default_charset` and `default_collation` from
`Generators::DeclareSchema::Migration::Migrator` to `::DeclareSchema`

## [0.8.0] - 2021-02-22
### Removed
- Removed assumption that primary key is named 'id'.
- Removed `sql_type` that was confusing because it was actually the same as `type` (ex: :string) and not
  in fact the SQL type (ex: ``varchar(255)'`).

## [0.7.1] - 2021-02-17
### Fixed
- Exclude unknown options from FieldSpec#sql_options and #schema_attributes.
- Fixed a bug where fk_field_options were getting merged into spec_attrs after checking for equivalence,
  leading to phantom migrations with no changes, or missing migrations when just the fk_field_options changed.

## [0.7.0] - 2021-02-14
### Changed
- Use `schema_attributes` for generating both up and down change migrations, so they are guaranteed to be symmetrical.
  Note: Rails schema dumper is still used for the down migration to replace a model that has been dropped.

## [0.6.4] - 2021-02-08
- Fixed a bug where the generated call to add_foreign_key() was not setting `column:`,
  so it only worked in cases where Rails could infer the foreign key by convention.

## [0.6.3] - 2021-01-21
### Added
- Added `add_foreign_key` native rails call in `DeclareSchema::Model::ForeignKeyDefinition#to_add_statement`.

### Fixed
- Fixed a bug in migration generation caused by `DeclareSchema::Migration#create_constraints`
  calling `DeclareSchema::Model::ForeignKeyDefinition#to_add_statement` with unused parameters.

- Fixed a bug in `DeclareSchema::Migration#remove_foreign_key` where special characters would not be quoted properly.

## [0.6.2] - 2021-01-06
### Added
- Added `sqlite3` as dev dependency for local development

### Fixed
- Fixed a bug in migration generation caused by `DeclareSchema::Model::ForeignKeyDefinition#to_add_statement`
  not being passed proper arguments.

## [0.6.1] - 2021-01-06
### Added
- Added Appraisals for MySQL as well as SQLite.

### Fixed
- Fixed case where primary key index will be gone by the time we get to dropping that primary key
because all of the existing primary key columns are being removed.

## [0.6.0] - 2020-12-23
### Added
- Fields may now be declared with `:bigint` type which is identical to `:integer, limit 8`
- FieldSpec#initialize interface now includes `position` keyword argument and `**options` hash.

### Fixed
- Fixed cycle in which FieldSpec#initialize was calling `model.field_specs`

### Changed
- Changed ci support from Travis to Github Workflow

## [0.5.0] - 2020-12-21
### Added
- Added support for configuring the character set and collation for MySQL databases
  at the global, table, and field level

## [0.4.2] - 2020-12-05
### Fixed
- Generalize the fix below to sqlite || Rails 4.

## [0.4.1] - 2020-12-04
### Fixed
- Fixed a bug detecting compound primary keys in Rails 4.

## [0.4.0] - 2020-11-20
### Added
- Fields may be declared with `serialize: true` (any value with a valid `.to_yaml` stored as YAML),
or `serialize: <serializeable-class>`, where `<serializeable-class>`
may be `Array` (`Array` stored as YAML) or `Hash` (`Hash` stored as YAML) or `JSON` (any value with a valid `.to_json`, stored as JSON)
or any custom serializable class.
This invokes `ActiveSupport`'s `serialize` macro for that field, passing the serializable class, if given.

  Note: when `serialize:` is used, any `default:` should be given in a matching Ruby type--for example, `[]` or `{}` or `{ 'currency' => 'USD' }`--in
which case the serializeable class will be used to determine the serialized default value and that will be set as the SQL default.

### Fixed
- Sqlite now correctly infers the PRIMARY KEY so it won't attempt to add that index again.

## [0.3.1] - 2020-11-13
### Fixed
- When passing `belongs_to` to Rails, suppress the `optional:` option in Rails 4, since that option was added in Rails 5.

## [0.3.0] - 2020-11-02
### Added
- Added support for `belongs_to optional:`.
If given, it is passed through to `ActiveRecord`'s `belong_to`.
If not given in Rails 5+, the `optional:` value is set equal to the `null:` value (default: `false`) and that
is passed to `ActiveRecord`'s `belong_to`.
Similarly, if `null:` is not given, it is inferred from `optional:`.
If both are given, their values are respected, even if contradictory;
this is a legitimate case when migrating to/from an optional association.
- Added a new callback `before_generating_migration` to the `Migrator` that can be
defined in order to custom load more models that might be missed by `eager_load!`
### Fixed
- Migrations are now generated where the `[4.2]` is only applied after `ActiveRecord::Migration` in Rails 5+ (since Rails 4 didn't know about that notation).

## [0.2.0] - 2020-10-26
### Added
- Automatically eager_load! all Rails::Engines before generating migrations.

### Changed
- Changed tests from rdoctest to rspec.

### Fixed
- Fixed a bug where `:text limit: 0xffff_ffff` (max size) was omitted from migrations.
- Fixed a bug where `:bigint` foreign keys were omitted from the migration.

## [0.1.3] - 2020-10-08
### Changed
- Updated the `always_ignore_tables` list in `Migrator` to access Rails metadata table names
using the appropriate Rails configuration attributes.

## [0.1.2] - 2020-09-29
### Changed
- Added travis support and created 2 specs as a starting point.

## [0.1.1] - 2020-09-24
### Added
- Initial version from https://github.com/Invoca/hobo_fields v4.1.0.
