# frozen_string_literal: true

module DeclareSchema
  module Model
    # A placeholder for a {FieldSpec} whose final shape can't be computed at field-
    # declaration time. The only producer today is `belongs_to` between two
    # declare_schema models: we cannot touch `reflection.klass` while declaring the
    # FK without risking a model-load cycle, so we stash an eager default-typed
    # FieldSpec along with a block that knows how to mirror the parent's PK once
    # all models have been eager-loaded.
    #
    # The migrator calls {#resolve} on every value in `field_specs` at the start
    # of migration generation (see `Migrator#generate`); for plain {FieldSpec}s
    # `#resolve` is a no-op returning self, while for instances of this class it
    # invokes the resolver block with the default spec and returns the produced
    # {FieldSpec}.
    class DeferredFieldSpec
      # @param default_spec [FieldSpec] the eager placeholder spec
      # @yieldparam default_spec [FieldSpec]
      # @yieldreturn [FieldSpec] the resolved spec
      def initialize(default_spec, &resolver)
        resolver or raise ArgumentError, "DeferredFieldSpec requires a resolver block"
        @default_spec = default_spec
        @resolver = resolver
      end

      # Resolve and memoize the produced FieldSpec. Memoization matters because
      # application code can hit several FieldSpec accessors per request; without
      # it each one would re-run the resolver and re-touch `reflection.klass`.
      #
      # @return [FieldSpec]
      def resolve
        @resolved ||= @resolver.call(@default_spec)
      end

      def respond_to_missing?(name, include_private = false)
        resolve.respond_to?(name, include_private) || super
      end

      def method_missing(name, *args, **kwargs, &)
        if resolve.respond_to?(name)
          resolve.public_send(name, *args, **kwargs, &)
        else
          super
        end
      end
    end
  end
end
