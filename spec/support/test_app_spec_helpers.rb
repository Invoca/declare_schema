# frozen_string_literal: true

RSpec.shared_context 'prepare test app' do
  before do
    load File.expand_path('./prepare_testapp.rb', __dir__)
  end
end
