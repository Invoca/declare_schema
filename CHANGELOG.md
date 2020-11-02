# CHANGELOG for `declare_schema`

Inspired by [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

Note: this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.3.0] - Unreleased
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

[0.3.0]: https://github.com/Invoca/declare_schema/compare/v0.2.0...v0.3.0
[0.2.0]: https://github.com/Invoca/declare_schema/compare/v0.1.3...v0.2.0
[0.1.3]: https://github.com/Invoca/declare_schema/compare/v0.1.2...v0.1.3
[0.1.2]: https://github.com/Invoca/declare_schema/compare/v0.1.1...v0.1.2
[0.1.1]: https://github.com/Invoca/declare_schema/tree/v0.1.1
