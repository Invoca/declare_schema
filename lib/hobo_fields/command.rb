# frozen_string_literal: true

require 'fileutils'
require 'tmpdir'
require 'rubygems'

module HoboFields
  module Command
    BANNER = <<~EOS
      Usage:
          hobofields new <app_name> [rails_opt]              Creates a new HoboFields Application
          hobofields generate|g <generator> [ARGS] [options] Fires the hobo:<generator>
          hobofields destroy <generator> [ARGS] [options]    Tries to undo generated code
          hobofields --help|-h                               This help screen

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
          template_path = File.join(Dir.tmpdir, "hobo_app_template")
          File.open(template_path, 'w') do |file|
            file.puts "gem '#{gem}', '>= #{version}'"
          end
          puts "Generating Rails infrastructure..."
          system("rails new #{app_name} #{args * ' '} -m #{template_path}")
          File.delete(template_path)

        when /^(g|generate|destroy)$/
          cmd = $1
          if args.empty?
            puts "\nThe generator name is missing!\n\n"
            puts BANNER
            exit(1)
          else
            if args.first =~ /^hobo:(\w+)$/
              puts "NOTICE: You can omit the 'hobo' namespace: e.g. `hobo #{cmd} #{$1} #{args[1..-1] * ' '}`"
            end
            system("bundle exec rails #{cmd} hobo:#{args * ' '}")
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
