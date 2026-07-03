# Design: Deprecate `Migrator.ignore_tables`/`ignore_models` in favor of `DeclareSchema.ignore_tables`/`ignore_models`

Jira: [OCTO-893](https://invoca.atlassian.net/browse/OCTO-893)

## Problem

`declare_schema`'s ignore-tables and ignore-models settings are currently configured
through an internal implementation class:

```ruby
::Generators::DeclareSchema::Migration::Migrator.ignore_tables = [...]
::Generators::DeclareSchema::Migration::Migrator.ignore_models = [...]
```

This leaks an internal `Migrator` class as public config API, inconsistent with the
gem's public `DeclareSchema` namespace. The two settings are exact parallels of each
other in the current code — same declaration, same init pattern, same usage style —
so this design treats them identically.

## Precedent

This exact situation was already solved once before, for `default_charset` and
`default_collation`, back in v0.10.0 (see `CHANGELOG.md`):

> Moved and deprecated default settings for `default_charset` and `default_collation`
> from `Generators::DeclareSchema::Migration::Migrator` to `::DeclareSchema`

The implementation lives in
`lib/generators/declare_schema/migration/migrator.rb`:

```ruby
delegate :default_charset=, :default_collation=, :default_charset, :default_collation, to: ::DeclareSchema
deprecate :default_charset=, :default_collation=, :default_charset, :default_collation, deprecator: ActiveSupport::Deprecation.new('1.0', 'declare_schema')
```

This design reuses that same pattern for both `ignore_tables` and `ignore_models`.

## Design

1. **`lib/declare_schema.rb`**
   - Add `@ignore_tables = []` and `@ignore_models = []` to the module's default instance
     variables.
   - Add `:ignore_tables, :ignore_models` to the module's `attr_accessor` list in `class << self`.

2. **`lib/generators/declare_schema/migration/migrator.rb`**
   - Remove `attr_accessor :ignore_models, :ignore_tables` entirely from `Migrator` (both
     settings move to `::DeclareSchema`; nothing is left behind on `Migrator`).
   - Add `:ignore_tables=, :ignore_tables, :ignore_models=, :ignore_models` to the existing
     `delegate ... to: ::DeclareSchema` line.
   - Add the same four methods to the existing `deprecate ...` line, reusing the same
     `ActiveSupport::Deprecation.new('1.0', 'declare_schema')` instance (no new deprecator).
   - Update the two internal callers in `models_and_tables` (currently `Migrator.ignore_tables`
     at line ~111 and `Migrator.ignore_models` at line ~104) to call `::DeclareSchema.ignore_tables`
     / `::DeclareSchema.ignore_models` directly, so normal migration generation doesn't trigger a
     deprecation warning on every run — matching how `default_charset`/`default_collation` are
     already called directly via `::DeclareSchema` elsewhere in this file.

3. **Tests** — `spec/lib/generators/declare_schema/migration/migrator_spec.rb`
   - Add `#ignore_tables` and `#ignore_models` describe blocks mirroring the existing
     `#default_charset` block: value passthrough (default `[]`, explicit set/reset) and
     deprecation-warning assertions for both the reader and writer of each.
   - Update `spec/lib/declare_schema/migration_generator_spec.rb` (the one existing spec that
     sets `Generators::DeclareSchema::Migration::Migrator.ignore_tables = ["green_fishes"]`)
     to use `::DeclareSchema.ignore_tables = [...]` instead, so that unrelated test doesn't
     emit deprecation noise.

4. **README.md**
   - Update the existing "Ignored Tables" section: primary documented setting becomes
     `::DeclareSchema.ignore_tables`, with a note that `Migrator.ignore_tables` is deprecated
     (still works, not removed).
   - Add a new "Ignored Models" section (not previously documented) covering
     `::DeclareSchema.ignore_models`, with the same deprecation note for
     `Migrator.ignore_models`.

5. **CHANGELOG.md**
   - New `## [4.1.0]` entry:
     - `### Added` — `::DeclareSchema.ignore_tables` and `::DeclareSchema.ignore_models` as
       the new public settings.
     - `### Deprecated` — `Generators::DeclareSchema::Migration::Migrator.ignore_tables` and
       `.ignore_models` in favor of the above; still function, will not be removed without a
       major version bump.

6. **Versioning**
   - Bump `4.0.3` → `4.1.0` (minor: new backward-compatible public API + non-breaking
     deprecation, nothing removed).
   - Separate commit touching only `lib/declare_schema/version.rb`, `Gemfile.lock`,
     `CHANGELOG.md`, matching the repo's existing release-commit convention (see `40f47e3`).

## Out of Scope

- No changes to any application code that consumes this gem (follow-up, not part of this ticket).
- No gem release / publish — implementation + local commits only, pending explicit
  go-ahead to push/release.

## Testing Plan

- Unit tests per above (delegation + deprecation warning) for both settings.
- Full existing spec suite must still pass (`bundle exec rspec`).
- `bundle exec rubocop` clean.
