# DeclareSchema.ignore_tables/ignore_models Deprecation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Move the `ignore_tables` and `ignore_models` settings from the internal `Generators::DeclareSchema::Migration::Migrator` class to the public `::DeclareSchema` module, keeping the old `Migrator` accessors working but deprecated.

**Architecture:** Reuse the exact pattern already used in this codebase for `default_charset`/`default_collation` (see `lib/generators/declare_schema/migration/migrator.rb`): the setting becomes a plain `attr_accessor` on `::DeclareSchema`, and `Migrator` gets `delegate ... to: ::DeclareSchema` + `deprecate ...` for the old names, sharing the existing `ActiveSupport::Deprecation.new('1.0', 'declare_schema')` instance.

**Tech Stack:** Ruby, Rails/ActiveSupport (`Module#delegate`, `Module#deprecate`, `ActiveSupport::Deprecation`), RSpec.

## Global Constraints

- No removal of `Migrator.ignore_tables`/`ignore_models` — deprecate only, so no major version bump is required.
- Version bump: `4.0.3` → `4.1.0` (minor).
- Spec reference: [OCTO-893](https://invoca.atlassian.net/browse/OCTO-893).
- Design doc: `docs/superpowers/specs/2026-07-03-ignore-tables-deprecation-design.md`.
- Work happens on branch `OCTO-893/deprecate-migrator-ignore-tables` (already created, already has 1 commit with the design doc).
- No gem release/publish and no push to `origin` as part of this plan — local commits only.

---

### Task 1: Move `ignore_tables`/`ignore_models` to `::DeclareSchema`, deprecate on `Migrator`

**Files:**
- Modify: `lib/declare_schema.rb`
- Modify: `lib/generators/declare_schema/migration/migrator.rb`
- Test: `spec/lib/generators/declare_schema/migration/migrator_spec.rb`
- Modify: `spec/lib/declare_schema/migration_generator_spec.rb:64`

**Interfaces:**
- Produces: `::DeclareSchema.ignore_tables` / `::DeclareSchema.ignore_tables=` (Array, default `[]`)
- Produces: `::DeclareSchema.ignore_models` / `::DeclareSchema.ignore_models=` (Array, default `[]`)
- Produces (deprecated but functional): `Generators::DeclareSchema::Migration::Migrator.ignore_tables` / `.ignore_tables=` / `.ignore_models` / `.ignore_models=`, all delegating to the `::DeclareSchema` versions above and emitting an `ActiveSupport::Deprecation` warning.

- [ ] **Step 1: Write the failing tests for the new deprecation behavior**

In `spec/lib/generators/declare_schema/migration/migrator_spec.rb`, insert these two new `describe` blocks immediately after the existing `describe '#default_collation'` block (which ends right before `describe '#load_rails_models'` at line 59):

```ruby
        describe '#ignore_tables' do
          subject { described_class.ignore_tables }

          context 'when not explicitly set' do
            it { should eq([]) }
          end

          context 'when explicitly set' do
            before { described_class.ignore_tables = ["green_fishes"] }
            after  { described_class.ignore_tables = [] }
            it     { should eq(["green_fishes"]) }
          end

          it 'should output deprecation warning' do
            expect { described_class.ignore_tables = ["green_fishes"] }.to output(/DEPRECATION WARNING: ignore_tables= is deprecated/).to_stderr
            expect { subject }.to output(/DEPRECATION WARNING: ignore_tables is deprecated/).to_stderr
          end

          after { ::DeclareSchema.ignore_tables = [] }
        end

        describe '#ignore_models' do
          subject { described_class.ignore_models }

          context 'when not explicitly set' do
            it { should eq([]) }
          end

          context 'when explicitly set' do
            before { described_class.ignore_models = ["Fish"] }
            after  { described_class.ignore_models = [] }
            it     { should eq(["Fish"]) }
          end

          it 'should output deprecation warning' do
            expect { described_class.ignore_models = ["Fish"] }.to output(/DEPRECATION WARNING: ignore_models= is deprecated/).to_stderr
            expect { subject }.to output(/DEPRECATION WARNING: ignore_models is deprecated/).to_stderr
          end

          after { ::DeclareSchema.ignore_models = [] }
        end
```

The outer `after` hooks in each block are a safety net so a failure mid-example (e.g. in the deprecation-warning test, which sets a non-default value but has no matching `after` of its own) can't leak state into later examples/spec files.

- [ ] **Step 2: Run the new tests to verify they fail**

Run: `bundle exec rspec spec/lib/generators/declare_schema/migration/migrator_spec.rb -e "#ignore_tables" -e "#ignore_models"`
Expected: FAIL — `NoMethodError: undefined method 'ignore_tables=' for Generators::DeclareSchema::Migration::Migrator` (the setter currently exists as a plain `attr_accessor`, so it won't yet raise a deprecation warning, so the "should output deprecation warning" examples fail with no output matching `/DEPRECATION WARNING/`).

- [ ] **Step 3: Add `ignore_tables`/`ignore_models` to `::DeclareSchema`**

In `lib/declare_schema.rb`, change:

```ruby
  @default_charset                      = "utf8mb4"
  @default_collation                    = "utf8mb4_bin"
  @default_text_limit                   = 0xffff_ffff
  @default_string_limit                 = nil
  @default_null                         = false
  @default_generate_foreign_keys        = true
  @default_generate_indexing            = true
  @db_migrate_command                   = "bundle exec rails db:migrate"

  class << self
    attr_writer :mysql_version
    attr_reader :default_text_limit, :default_string_limit, :default_null,
                :default_generate_foreign_keys, :default_generate_indexing, :db_migrate_command
```

to:

```ruby
  @default_charset                      = "utf8mb4"
  @default_collation                    = "utf8mb4_bin"
  @default_text_limit                   = 0xffff_ffff
  @default_string_limit                 = nil
  @default_null                         = false
  @default_generate_foreign_keys        = true
  @default_generate_indexing            = true
  @db_migrate_command                   = "bundle exec rails db:migrate"
  @ignore_tables                        = []
  @ignore_models                        = []

  class << self
    attr_writer :mysql_version
    attr_accessor :ignore_tables, :ignore_models
    attr_reader :default_text_limit, :default_string_limit, :default_null,
                :default_generate_foreign_keys, :default_generate_indexing, :db_migrate_command
```

- [ ] **Step 4: Delegate and deprecate on `Migrator`, remove its own accessors**

In `lib/generators/declare_schema/migration/migrator.rb`, change:

```ruby
        @ignore_models                        = []
        @ignore_tables                        = []
        @before_generating_migration_callback = nil
        @active_record_class                  = ActiveRecord::Base

        class << self
          attr_accessor :ignore_models, :ignore_tables
          attr_reader :active_record_class, :before_generating_migration_callback
```

to:

```ruby
        @before_generating_migration_callback = nil
        @active_record_class                  = ActiveRecord::Base

        class << self
          attr_reader :active_record_class, :before_generating_migration_callback
```

Then change:

```ruby
          delegate :default_charset=, :default_collation=, :default_charset, :default_collation, to: ::DeclareSchema
          deprecate :default_charset=, :default_collation=, :default_charset, :default_collation, deprecator: ActiveSupport::Deprecation.new('1.0', 'declare_schema')
        end
```

to:

```ruby
          delegate :default_charset=, :default_collation=, :default_charset, :default_collation,
                   :ignore_tables=, :ignore_tables, :ignore_models=, :ignore_models, to: ::DeclareSchema
          deprecate :default_charset=, :default_collation=, :default_charset, :default_collation,
                    :ignore_tables=, :ignore_tables, :ignore_models=, :ignore_models,
                    deprecator: ActiveSupport::Deprecation.new('1.0', 'declare_schema')
        end
```

- [ ] **Step 5: Update the internal caller to avoid triggering the new deprecation warning**

Still in `lib/generators/declare_schema/migration/migrator.rb`, in `models_and_tables`, change:

```ruby
        def models_and_tables
          ignore_model_names = Migrator.ignore_models.map { |model| model.to_s.underscore }
          all_models = table_model_classes
          declare_schema_models = all_models.select do |m|
            (m.name['HABTM_'] ||
              (m.include_in_migration if m.respond_to?(:include_in_migration))) && !m.name.underscore.in?(ignore_model_names)
          end
          non_declare_schema_models = all_models - declare_schema_models
          db_tables = connection.tables - Migrator.ignore_tables.map(&:to_s) - non_declare_schema_models.map(&:table_name)
          [declare_schema_models, db_tables]
        end
```

to:

```ruby
        def models_and_tables
          ignore_model_names = ::DeclareSchema.ignore_models.map { |model| model.to_s.underscore }
          all_models = table_model_classes
          declare_schema_models = all_models.select do |m|
            (m.name['HABTM_'] ||
              (m.include_in_migration if m.respond_to?(:include_in_migration))) && !m.name.underscore.in?(ignore_model_names)
          end
          non_declare_schema_models = all_models - declare_schema_models
          db_tables = connection.tables - ::DeclareSchema.ignore_tables.map(&:to_s) - non_declare_schema_models.map(&:table_name)
          [declare_schema_models, db_tables]
        end
```

- [ ] **Step 6: Run the new tests to verify they pass**

Run: `bundle exec rspec spec/lib/generators/declare_schema/migration/migrator_spec.rb -e "#ignore_tables" -e "#ignore_models"`
Expected: PASS (6 examples, 0 failures)

- [ ] **Step 7: Update the pre-existing spec that used the now-deprecated setter**

In `spec/lib/declare_schema/migration_generator_spec.rb:64`, change:

```ruby
      Generators::DeclareSchema::Migration::Migrator.ignore_tables = ["green_fishes"]
```

to:

```ruby
      ::DeclareSchema.ignore_tables = ["green_fishes"]
```

This avoids emitting an unrelated deprecation warning every time this (large, pre-existing) integration test runs.

- [ ] **Step 8: Run the full test suite**

Run: `bundle exec rspec`
Expected: All examples pass, 0 failures (same pass count as before this task, plus the 6 new examples from Step 1).

- [ ] **Step 9: Run Rubocop**

Run: `bundle exec rubocop lib/declare_schema.rb lib/generators/declare_schema/migration/migrator.rb spec/lib/generators/declare_schema/migration/migrator_spec.rb spec/lib/declare_schema/migration_generator_spec.rb`
Expected: No offenses.

- [ ] **Step 10: Commit**

```bash
git add lib/declare_schema.rb lib/generators/declare_schema/migration/migrator.rb spec/lib/generators/declare_schema/migration/migrator_spec.rb spec/lib/declare_schema/migration_generator_spec.rb
git commit -m "OCTO-893: Deprecate Migrator.ignore_tables/ignore_models

Move ignore_tables and ignore_models to ::DeclareSchema, following the
same delegate+deprecate pattern already used for default_charset and
default_collation. The Migrator accessors keep working but emit an
ActiveSupport deprecation warning; nothing is removed."
```

---

### Task 2: Document the new settings in the README

**Files:**
- Modify: `README.md:377-394` (existing "Ignored Tables" section)

**Interfaces:**
- Consumes: `::DeclareSchema.ignore_tables` / `::DeclareSchema.ignore_models` from Task 1 (must already exist and work).

- [ ] **Step 1: Update the "Ignored Tables" section and add a new "Ignored Models" section**

In `README.md`, change:

```markdown
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
```

to:

```markdown
## Ignored Tables
If a table's schema or metadata are managed elsewhere, `declare_schema` can be instructed to ignore it
by adding those table names to the array assigned to `DeclareSchema.ignore_tables`.
For example:

```ruby
::DeclareSchema.ignore_tables = [
  "delayed_jobs",
  "my_snowflake_table",
  ...
]
```

**Deprecated:** `Generators::DeclareSchema::Migration::Migrator.ignore_tables` is a deprecated alias for
`DeclareSchema.ignore_tables` above. It still works, but new code should use `DeclareSchema.ignore_tables`
directly.

Note: `declare_schema` always ignores these tables:
- The ActiveRecord `schema_info` table
- The ActiveRecord schema migrations table (generally named `schema_migrations`)
- The ActiveRecord internal metadata table (generally named `ar_internal_metadata`)
- If defined/configured, the CGI ActiveRecordStore session table

## Ignored Models
Similarly, `declare_schema` can be instructed to ignore specific models (so that no migration is
generated for their table) by adding the model's underscored name to the array assigned to
`DeclareSchema.ignore_models`. For example:

```ruby
::DeclareSchema.ignore_models = [
  "my_legacy_model",
  ...
]
```

**Deprecated:** `Generators::DeclareSchema::Migration::Migrator.ignore_models` is a deprecated alias for
`DeclareSchema.ignore_models` above. It still works, but new code should use `DeclareSchema.ignore_models`
directly.
```

- [ ] **Step 2: Verify the README's fenced code blocks are balanced**

Run: `grep -c '^```' README.md`
Expected: An even number (each opened fence is closed).

- [ ] **Step 3: Commit**

```bash
git add README.md
git commit -m "OCTO-893: Document DeclareSchema.ignore_tables and ignore_models

Update the README's Ignored Tables section to point at the new public
DeclareSchema.ignore_tables setting, and add a new Ignored Models
section documenting DeclareSchema.ignore_models. Both note that the
old Migrator-based settings are deprecated aliases."
```

---

### Task 3: Bump version and update CHANGELOG

**Files:**
- Modify: `lib/declare_schema/version.rb`
- Modify: `Gemfile.lock`
- Modify: `CHANGELOG.md`

**Interfaces:**
- Consumes: nothing new — this is a release-metadata-only task, done after Tasks 1 and 2 are committed.

- [ ] **Step 1: Bump the version**

In `lib/declare_schema/version.rb`, change:

```ruby
module DeclareSchema
  VERSION = "4.0.3"
end
```

to:

```ruby
module DeclareSchema
  VERSION = "4.1.0"
end
```

- [ ] **Step 2: Update Gemfile.lock**

Run: `bundle install`
Expected: `Gemfile.lock`'s `PATH` section updates from `declare_schema (4.0.3)` to `declare_schema (4.1.0)`, and the `DEPENDENCIES`/lockfile line for `declare_schema (= 4.1.0)` (if present) updates to match.

- [ ] **Step 3: Add the CHANGELOG entry**

In `CHANGELOG.md`, change:

```markdown
Note: this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [4.0.3] - 2026-07-01
```

to (using today's actual date when this step is executed):

```markdown
Note: this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [4.1.0] - 2026-07-03
### Added
- `::DeclareSchema.ignore_tables` and `::DeclareSchema.ignore_models` as the new public
  settings for ignoring tables/models during migration generation.

### Deprecated
- `Generators::DeclareSchema::Migration::Migrator.ignore_tables` and `.ignore_models` in
  favor of `DeclareSchema.ignore_tables` and `DeclareSchema.ignore_models` above. The
  `Migrator` accessors still work but emit a deprecation warning; they will not be
  removed without a major version bump.

## [4.0.3] - 2026-07-01
```

- [ ] **Step 4: Run the full test suite one more time**

Run: `bundle exec rspec`
Expected: All examples pass, 0 failures.

- [ ] **Step 5: Commit**

```bash
git add lib/declare_schema/version.rb Gemfile.lock CHANGELOG.md
git commit -m "Bump version to 4.1.0

Adds DeclareSchema.ignore_tables/ignore_models (OCTO-893), deprecating
the old Migrator-based settings without removing them."
```

---

## After This Plan

- Do **not** push the branch, open a PR, or run `rake release` — those are explicit go/no-go decisions for the user, out of scope for this plan.
- Once the user reviews the local commits, they can decide whether to push `OCTO-893/deprecate-migrator-ignore-tables` and open a PR.
