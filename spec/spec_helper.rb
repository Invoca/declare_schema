# frozen_string_literal: true

require "bundler/setup"
require "declare_schema"
require "climate_control"

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = ".rspec_status"

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |expectations|
    expectations.syntax = :expect
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end
  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end
  config.shared_context_metadata_behavior = :apply_to_host_groups

  RSpec::Support::ObjectFormatter.default_instance.max_formatted_output_length = 2_000

  def active_record_base_class
    if Rails::VERSION::MAJOR == 4
      'ActiveRecord::Base'
    else
      'ApplicationRecord'
    end
  end

  def migrate(renames = {})
    up, down = Generators::DeclareSchema::Migration::Migrator.run(renames)
    ActiveRecord::Migration.class_eval(up)
    ActiveRecord::Base.send(:descendants).each { |model| model.reset_column_information }
    [up, down]
  end

  def nuke_model_class(klass)
    ActiveSupport::DescendantsTracker.instance_eval do
      direct_descendants = class_variable_get('@@direct_descendants')
      direct_descendants[ActiveRecord::Base] = direct_descendants[ActiveRecord::Base].to_a.reject { |descendant| descendant == klass }
      if defined?(ApplicationRecord)
        direct_descendants[ApplicationRecord] = direct_descendants[ApplicationRecord].to_a.reject { |descendant| descendant == klass }
      end
    end
    Object.instance_eval { remove_const(klass.name.to_sym) rescue nil }
  end

  def with_modified_env(options, &block)
    ClimateControl.modify(options, &block)
  end
end
