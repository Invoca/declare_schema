# CHANGELOG for `declare_schema`

Inspired by [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

Note: this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.2.0] - Unreleased
### Added
- Automatically eager_load! all Rails::Engines before generating migrations.

### Changed
- Changed tests from rdoctest to rspec.

## [0.1.3] - Unreleased
### Changed
- Updated the `always_ignore_tables` list in `Migrator` to access Rails metadata table names
using the appropriate Rails configuration attributes.

## [0.1.2] - 2020-09-29
### Changed
- Added travis support and created 2 specs as a starting point.


## [0.1.1] - 2020-09-24
### Added
- Initial version from https://github.com/Invoca/hobo_fields v4.1.0.

[0.2.0]: https://github.com/Invoca/declare_schema/compare/v0.1.3...v0.2.0
[0.1.3]: https://github.com/Invoca/declare_schema/compare/v0.1.2...v0.1.3
[0.1.2]: https://github.com/Invoca/declare_schema/compare/v0.1.1...v0.1.2
[0.1.1]: https://github.com/Invoca/declare_schema/tree/v0.1.1
