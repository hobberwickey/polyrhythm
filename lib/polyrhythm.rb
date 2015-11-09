require "polyrhythm/version"
require 'fileutils'
require "json"
require 'erb'
require 'readline'

module Polyrhythm
  class Scaffold
    DEFAULT_SERVICES = {
      :development => {
        :local => {},
        :remote => {}
      }
    }

    DEFAULT_CONFIG = {
      :db_roots => {
        :pg => "postgres",
      },  

      :db_ports => {
        :pg => "5432"
      },
    }

    # DEFAULT_CONFIG = {
    #   :db_roots => {
    #     :pg => "postgres",
    #   },  

    #   :db_ports => {
    #     :pg => "5432"
    #   },

    #   :db_user => "DB_USERNAME",
    #   :db_pass => "DB_PASSWORD",
    #   :db_name => "DB_NAME",
    #   :db_host => "localhost",
    #   :db_port => nil,
    #   :db_type => "pg",
    #   :without_cors => false
    # }

    def initialize
      @app_root = Dir.pwd
      @gem_root = File.expand_path '../..', __FILE__      
    end
    
    def input(prompt="", newline=false)
      prompt += "\n" if newline
      Readline.readline(prompt, true).squeeze(" ").strip
    end

    def init
      @services = DEFAULT_SERVICES.clone

      FileUtils::copy "#{@gem_root}/lib/core/config.ru", "#{@app_root}/config.ru"
      FileUtils::copy "#{@gem_root}/lib/core/Gemfile", "#{@app_root}/Gemfile"
      
      #write_services
      
      # TODO: error checking
      build_service
      build_auth if input("Would you like to install the authorization service now? (y/n)") == "y"
    end

    def build_service
      if not (defined? @name && defined? @path)
        @name = input("Service name? ")
        @path = input("Service path? ")
      end
      
      #@db_adapter = ("What database adpater would you like to use? ")
      @db_adapter = "pg"

      @db_name = input("Database name? ")
      @db_user = input("Database username? ")
      @db_pass = input("Database password? ")
      @config = DEFAULT_CONFIG.clone
      
      unless defined? @services 
        require "#{@app_root}/services"
        @services = SERVICES
      end

      write_services

      dir = "#{@app_root}/#{@name.downcase}"
      FileUtils.cp_r "#{@gem_root}/lib/service/.", dir

      build_from_template "#{@gem_root}/lib/templates/env.erb", "#{dir}/.env"
      build_from_template "#{@gem_root}/lib/templates/application.erb", "#{dir}/#{@name}.rb"
      build_from_template "#{@gem_root}/lib/templates/helpers.erb", "#{@app_root}/lib/helpers.rb"
      build_from_template "#{@gem_root}/lib/templates/gemfile.erb", "#{@app_root}/Gemfile", 'a+'
      
      #TODO: move into a gem
      build_from_template "#{@gem_root}/lib/templates/siren.erb", "#{@app_root}/lib/api/siren.rb"
      build_from_template "#{@gem_root}/lib/templates/api.erb", "#{@app_root}/lib/api/api.rb"
    end

    def build_auth
      @name = "authorization"
      @path = "/authorization"

      build_service
    end

    # def _init(name, path, opts={})
    #   @name = name
    #   @path = path
    #   @config = DEFAULT_CONFIG.merge(opts)

    #   @services = DEFAULT_SERVICES.clone
    #   FileUtils::copy "#{@gem_root}/lib/core/config.ru", "#{@app_root}/config.ru"
    #   FileUtils::copy "#{@gem_root}/lib/core/Gemfile", "#{@app_root}/Gemfile"
      
    #   write_services
    #   build_service(nil, @path, opts)
    # end
    
    # def _build_service(name, path, opts={})
    #   unless defined? @name 
    #     require "#{@app_root}/services"

    #     @name = name
    #     @config = DEFAULT_CONFIG.merge(opts)
    #     @services = SERVICES
    #     write_services
    #   end

    #   unless path.nil?
    #     @path = path
    #   else
    #     #error
    #   end

    #   if defined? @name 
    #     dir = "#{@app_root}/#{@name.downcase}"
    #     FileUtils.cp_r "#{@gem_root}/lib/service/.", dir

    #     build_from_template "#{@gem_root}/lib/templates/env.erb", "#{dir}/.env"
    #     build_from_template "#{@gem_root}/lib/templates/application.erb", "#{dir}/#{@name}.rb"
    #     build_from_template "#{@gem_root}/lib/templates/gemfile.erb", "#{@app_root}/Gemfile", 'a+'
    #   else 
    #     #error
    #   end

    # end

    def remote_service(name, opts={})

    end

    private

    def build_from_template(src, dest, mode='w+')
      template = File.open(src, 'r')
      parsed = ERB.new(template.read).result( binding )

      File.open(dest, mode){ |f| f.write ( parsed )}
      template.close
    end

    def write_services
      #TODO: better checks
      if @services[:development][:local][@path].nil?  && @services[:development][:remote][@path].nil?
        @services[:development][:local][@path] = @name.downcase

        File.open("#{@app_root}/services.rb", "w+"){ |f| f.write(
          "SERVICES = #{@services.to_s}"
        )}
      else
        
      end
    end
  end


  # class Setup
  #   def self.scaffold
  #     create_server
  #     create_client
  #     create_auth
  #   end

  #   def self.create_server
  #     app_root = Dir.pwd
  #     gem_root = File.expand_path '../..', __FILE__

  #     FileUtils.cp_r "#{gem_root}/lib/server/.", app_root
  #   end

  #   def self.create_client
  #     app_root = Dir.pwd
  #     gem_root = File.expand_path '../..', __FILE__

  #     FileUtils.cp_r "#{gem_root}/lib/client/.", app_root
  #   end

  #   def self.create_auth(path="")
  #     app_root = "#{Dir.pwd}path"
  #     gem_root = File.expand_path '../..', __FILE__

  #     FileUtils.cp_r "#{gem_root}/lib/authorization/.", app_root
  #   end

  #   def self.create_model(name)
  #     puts Dir.pwd
  #   end

  #   def self.create_migration(name)
  #     puts "NAME: #{name.capitalize}"
  #   end
  # end
end
