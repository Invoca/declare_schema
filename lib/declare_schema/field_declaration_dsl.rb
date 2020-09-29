# frozen_string_literal: true

require 'active_support/proxy_object'

module DeclareSchema
  class FieldDeclarationDsl < BasicObject # avoid Object because that gets extended by lots of gems
    include ::Kernel                      # but we need the basic class methods

    instance_methods.each do |m|
      unless m.to_s.starts_with?('__') || m.in?([:object_id, :instance_eval])
        undef_method(m)
      end
    end

    def initialize(model, options = {})
      @model = model
      @options = options
    end

    attr_reader :model

    def timestamps
      field(:created_at, :datetime, null: true)
      field(:updated_at, :datetime, null: true)
    end

    def optimistic_lock
      field(:lock_version, :integer, default: 1, null: false)
    end

    def field(name, type, *args)
      options = args.extract_options!
      @model.declare_field(name, type, *(args + [@options.merge(options)]))
    end

    def method_missing(name, *args)
      field(name, args.first, *args[1..-1])
    end
  end
end
