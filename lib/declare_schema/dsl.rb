# frozen_string_literal: true

require 'active_support/proxy_object'

module DeclareSchema
  class Dsl < BasicObject # avoid Object because that gets extended by lots of gems
    include ::Kernel      # but we need the basic class methods

    instance_methods.each do |m|
      unless m.to_s.starts_with?('__') || m.in?([:object_id, :instance_eval, :instance_exec])
        undef_method(m)
      end
    end

    def initialize(model, **options)
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

    def field(name, type, *args, **options)
      @model.declare_field(name, type, *args, **@options.merge(options))
    end

    # TODO: make [:required] just another option. Either 'required: true] or 'optional: false'?
    def method_missing(*args, **options)
      args.count(&:itself) >= 2 or raise ::ArgumentError, "fields in declare_schema block must be declared as: type name, [:required], options (got #{args.inspect}, #{options.inspect})"
      type, name, *required = args
      field(name, type, *required, **options)
    end
  end
end
