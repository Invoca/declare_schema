# frozen_string_literal: true

RSpec.shared_context 'skip if' do
  around do |spec|
    if ActiveRecord::Base.connection_config[:adapter] == adapter
      spec.skip
    else
      spec.run
    end
  end
end

RSpec.shared_context 'skip unless' do
  around do |spec|
    if ActiveRecord::Base.connection_config[:adapter] != adapter
      spec.skip
    else
      spec.run
    end
  end
end
