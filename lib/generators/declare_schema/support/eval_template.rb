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
              erb = ERB.new(::File.read(source).force_encoding(Encoding::UTF_8), trim_mode: '>')
              erb.filename = source
              begin
                erb.result(binding)
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
