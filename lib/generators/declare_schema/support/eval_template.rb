# frozen_string_literal: true

module DeclareSchema
  module Support
    module EvalTemplate
      class << self
        def included(base)
          base.class_eval do
            private

            def eval_template(template_name)
              source  = File.expand_path(find_in_source_paths(template_name))
              context = instance_eval('binding')
              ERB.new(::File.binread(source), trim_mode: '-').tap { |erb| erb.filename = source }.result(context)
            end
          end
        end
      end
    end
  end
end
