# frozen_string_literal: true

require 'fileutils'
require 'tmpdir'
require 'rubygems'

module DeclareSchema
  module Command
    BANNER = <<~EOS
      Usage:
          declare_schema new <app_name> [rails_opt]              Creates a new declare_schema Application
          declare_schema generate|g <generator> [ARGS] [options] Fires the declare_schema:<generator>
          declare_schema destroy <generator> [ARGS] [options]    Tries to undo generated code
          declare_schema --help|-h                               This help screen

    EOS

    class << self
      def run(gem, args, version)
        command = args.shift

        case command

        when nil
          puts "\nThe command is missing!\n\n"
          puts BANNER
          exit(1)

        when /^--help|-h$/
          puts BANNER
          exit

        when 'new'
          app_name = args.shift or begin
            puts "\nThe application name is missing!\n\n"
            puts BANNER
            exit(1)
          end
          template_path = File.join(Dir.tmpdir, "declare_schema_app_template")
          File.open(template_path, 'w') do |file|
            file.puts "gem '#{gem}', '>= #{version}'"
          end
          puts "Generating Rails infrastructure..."
          database_option =
            begin
              require 'mysql2'
              ' -d mysql'
            rescue LoadError
            end
          puts("rails new #{app_name} #{args * ' '} -m #{template_path}#{database_option}")
          system("rails new #{app_name} #{args * ' '} -m #{template_path}#{database_option}")
          File.delete(template_path)

        when /^(g|generate|destroy)$/
          cmd = Regexp.last_match(1)
          if args.empty?
            puts "\nThe generator name is missing!\n\n"
            puts BANNER
            exit(1)
          else
            system("bundle exec rails #{cmd} declare_schema:#{args * ' '}")
          end

        else
          puts "\n  => '#{command}' is an unknown command!\n\n"
          puts BANNER
          exit(1)
        end
      end
    end
  end
end
