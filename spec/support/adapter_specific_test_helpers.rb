# frozen_string_literal: true

RSpec.shared_context 'skip if' do
  around do |spec|
    if current_adapter == adapter
      spec.skip
    else
      spec.run
    end
  end
end

RSpec.shared_context 'skip unless' do
  around do |spec|
    if current_adapter != adapter
      spec.skip
    else
      spec.run
    end
  end
end

def current_adapter(model_class = ActiveRecord::Base)
  if Rails::VERSION::MAJOR >= 7
    model_class.connection_db_config.adapter
  else
    model_class.connection_config[:adapter]
  end
end
