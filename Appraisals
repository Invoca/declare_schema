# frozen_string_literal: true

appraise 'rails-6-sqlite' do
  gem 'rails', '~> 6.1'
  gem 'sqlite3'
end

appraise 'rails-6-mysql' do
  gem 'rails', '~> 6.1'
  gem 'mysql2'
  remove_gem 'sqlite3'
end
