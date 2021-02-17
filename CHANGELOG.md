# CHANGELOG for `declare_schema`

Inspired by [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

Note: this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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

[0.7.1]: https://github.com/Invoca/declare_schema/compare/v0.7.0...v0.7.1
[0.7.0]: https://github.com/Invoca/declare_schema/compare/v0.6.3...v0.7.0
[0.6.4]: https://github.com/Invoca/declare_schema/compare/v0.6.3...v0.6.4
[0.6.3]: https://github.com/Invoca/declare_schema/compare/v0.6.2...v0.6.3
[0.6.2]: https://github.com/Invoca/declare_schema/compare/v0.6.1...v0.6.2
[0.6.1]: https://github.com/Invoca/declare_schema/compare/v0.6.0...v0.6.1
[0.6.0]: https://github.com/Invoca/declare_schema/compare/v0.5.0...v0.6.0
[0.5.0]: https://github.com/Invoca/declare_schema/compare/v0.4.2...v0.5.0
[0.4.2]: https://github.com/Invoca/declare_schema/compare/v0.4.1...v0.4.2
[0.4.1]: https://github.com/Invoca/declare_schema/compare/v0.4.0...v0.4.1
[0.4.0]: https://github.com/Invoca/declare_schema/compare/v0.3.1...v0.4.0
[0.3.1]: https://github.com/Invoca/declare_schema/compare/v0.3.0...v0.3.1
[0.3.0]: https://github.com/Invoca/declare_schema/compare/v0.2.0...v0.3.0
[0.2.0]: https://github.com/Invoca/declare_schema/compare/v0.1.3...v0.2.0
[0.1.3]: https://github.com/Invoca/declare_schema/compare/v0.1.2...v0.1.3
[0.1.2]: https://github.com/Invoca/declare_schema/compare/v0.1.1...v0.1.2
[0.1.1]: https://github.com/Invoca/declare_schema/tree/v0.1.1
