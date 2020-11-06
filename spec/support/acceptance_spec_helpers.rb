# frozen_string_literal: true

module AcceptanceSpecHelpers
  def generate_model(model_name, *fields)
    Rails::Generators.invoke('declare_schema:model', [model_name, *fields])
  end

  def generate_migrations(*flags)
    Rails::Generators.invoke('declare_schema:migration', flags)
  end

  def expect_model_definition_to_eq(model, expectation)
    model_file_path = "#{TESTAPP_PATH}/app/models/#{model}.rb"

    expect(File.exist?(model_file_path)).to be_truthy
    expect(File.read(model_file_path)).to eq(expectation)
  end

  def expect_test_definition_to_eq(model, expectation)
    test_file_path = "#{TESTAPP_PATH}/test/models/#{model}_test.rb"

    expect(File.exist?(test_file_path)).to be_truthy
    expect(File.read(test_file_path)).to eq(expectation)
  end

  def expect_test_fixture_to_eq(model, expectation)
    fixture_file_path = "#{TESTAPP_PATH}/test/fixtures/#{model}.yml"

    expect(File.exist?(fixture_file_path)).to be_truthy
    expect(File.read(fixture_file_path)).to eq(expectation)
  end

  def clean_up_model(model)
    system("rm -rf #{TESTAPP_PATH}/app/models/#{model}.rb #{TESTAPP_PATH}/test/models/#{model}.rb #{TESTAPP_PATH}/test/fixtures/#{model}.rb")
  end

  def load_models
    Rails.application.config.autoload_paths += ["#{TESTAPP_PATH}/app/models"]
    $LOAD_PATH << "#{TESTAPP_PATH}/app/models"
  end

  def migrate_up(expected_value)
    MigrationUpEquals.new(expected_value)
  end

  def migrate_down(expected_value)
    MigrationDownEquals.new(expected_value)
  end

  class MigrationUpEquals < RSpec::Matchers::BuiltIn::Eq
    def matches?(subject)
      super(subject[0])
    end
  end

  class MigrationDownEquals < RSpec::Matchers::BuiltIn::Eq
    def matches?(subject)
      super(subject[1])
    end
  end
end
