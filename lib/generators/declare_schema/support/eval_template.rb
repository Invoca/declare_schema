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
              erb = ERB.new(::File.binread(source), trim_mode: '>')
              erb.filename = source
              erb.lineno = 1
              begin
                erb.result(context)
              rescue Exception => ex
                raise ex.class, <<~EOS
                  #{ex.message}
                  #{erb.src}
                    #{ex.backtrace.join("\n  ")}
                EOS
              end
            end
          end
        end
      end
    end
  end
end
