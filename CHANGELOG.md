# CHANGELOG for `hobo_fields`

Inspired by [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

Note: this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [4.0.0] - Unreleased
### Changed
- Removed automatic scaling of `:text :limit` by / UTF8_BYTES_PER_CHAR = 3.

### Added
- When using MySQL, `:text :limit` is now rounded up to nearest supported size, with a default of the max (LONGTEXT) size, `0xffff_ffff`.
For other databases, `:text :limit` is ignored.


## [3.1.0] - 2020-07-21
### Added
- Added support for Rails 6

### Fixed
- Fixed backwards compatibility with `rails` version `4.2` that was broken in version `3.0.0`

### Removed
- Removed support for rich type classes like `Markdown` and `HTML` text fields

[4.0.0]: https://github.com/Invoca/hobo_fields/compare/v3.1.0...v4.0.0
[3.1.0]: https://github.com/Invoca/pnapi_models/tree/v3.1.0
