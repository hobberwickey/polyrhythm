require "polyrhythm/version"
require 'fileutils'
require "json"
require 'erb'
require 'readline'
require 'active_support/inflector'

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

    def init
      @config = JSON.parse( File.read("./core/config.json"), {:symbolize_names => true})

      FileUtils::copy "#{@gem_root}/lib/core/config.ru", "#{@app_root}/config.ru"
      FileUtils::copy "#{@gem_root}/lib/core/Gemfile", "#{@app_root}/Gemfile"
      
      if input("Would you like to install the authorization service now? (y/n)") == "y"
        build_auth
      else
        #TODO: See if another auth service should be used
        write_config
      end
    end

    def build_service
      if not defined? @name and not defined? @path
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

      build_from_template "env.erb", "#{dir}/.env"
      build_from_template "application.erb", "#{dir}/#{@name}.rb"
      build_from_template "helpers.erb", "#{dir}/lib/helpers.rb"
      build_from_template "gemfile.erb", "#{@app_root}/Gemfile", 'a+'
      
      #TODO: move into a gem
      build_from_template "siren.erb", "#{dir}/lib/api/siren.rb"
      build_from_template "api.erb", "#{dir}/lib/api/api.rb"
    end

    def build_auth
      
    end

    def create_model(name, root=nil)
      @name = name
      @root = root || Dir.pwd

      build_from_template "model.erb", "#{@root}/models/#{@name.downcase.singularize}.rb"

      create_migration("create_#{@name}", @root)
    end

    def create_migration(name, root=nil)
      @name = name
      @root = root || Dir.pwd

      build_from_template "migration.erb", "#{@root}/db/migrate/#{Time.now.to_i}_#{@name}.rb"
    end

    def remote_service(name, opts={})

    end

    private

    def input(prompt="", newline=false)
      prompt += "\n" if newline
      Readline.readline(prompt, true).squeeze(" ").strip
    end

    def build_from_template(src, dest, mode='w+')
      template = File.open("#{@gem_root}/lib/templates/#{src}", 'r')
      parsed = ERB.new(template.read).result( binding )

      ensure_directory_exists(dest)
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

    def write_config
      File.open("@app_root/config.json","w") do |f|
        f.write( JSON.pretty_generate(@config) )
      end
    end

    def ensure_directory_exists(dest)
      dirname = File.dirname(dest)
      unless File.directory?(dirname)
        FileUtils.mkdir_p(dirname)
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
