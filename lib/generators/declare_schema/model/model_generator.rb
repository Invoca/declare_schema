# frozen_string_literal: true

require 'rails/generators/active_record'
require 'generators/declare_schema/support/model'

module DeclareSchema
  class ModelGenerator < ActiveRecord::Generators::Base
    source_root File.expand_path('../templates', __FILE__)

    include DeclareSchema::Support::Model
  end
end
