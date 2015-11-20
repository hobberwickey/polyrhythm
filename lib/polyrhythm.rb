require "polyrhythm/version"
require 'fileutils'
require "json"
require 'erb'
require 'readline'
require 'active_support/inflector'
require "bcrypt"
      

module Polyrhythm
  class Scaffold
    include BCrypt

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
      @config = JSON.parse( File.read("#{@gem_root}/lib/core/config.json"), {:symbolize_names => true})
      
      FileUtils::copy "#{@gem_root}/lib/core/config.ru", "#{@app_root}/config.ru"
      FileUtils::copy "#{@gem_root}/lib/core/Gemfile", "#{@app_root}/Gemfile"
      
      puts "Building root service"
      puts ""

      root_db = {
        :adapter => "pg", #input("Root service database adpater (default 'pg') ")
        :user_name => input("Database user name"),
        :password => input("Database password"),
        :name => input("Database name")
      }

      build_service("application", "/", root_db)

      puts "Root service built"
      puts ""

      if input("Would you like to install the authorization service now? (y/n) ") == "y"
        build_auth
      else
        #TODO: See if another auth service should be used
        write_config
      end
    end

    def build_service(name, path, db_config)
      @name = name
      @path = path
      @db = db_config

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

    def _build_service
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
      require "active_record"

      FileUtils.cp_r "#{@gem_root}/authorization", "#{@app_root}/authorization"

      @config[:authorization][:name] = input("What would you like your authorization service to be named? (default: authorization) ")
      @config[:authorization][:require_username] = input("Would you like to require a username for authorization? y/n" ) == "y" ? true : false
      @config[:authorization][:require_email] = input("Would you like to require an email for authorization? y/n" ) == "y" ? true : false
      puts "Database configuration:"
      
      db_settings = @config[:authorization][:database]
      db_settings[:adapter] = "pg" #TODO: for now
      db_settings[:username] = input("Database username?" ) 
      db_settings[:password] = input("Database password?" ) 
      db_settings[:name] = input("Database name?" ) 

      db_settings[:url] = "#{ DEFAULT_CONFIG[:db_roots][db_settings[:adapter].to_sym] }://#{ db_settings[:username] }#{ db_settings[:password] != '' ? '' : ':' }#{ db_settings[:password] }@localhost:#{ DEFAULT_CONFIG[:db_ports][db_settings[:adapter].to_sym] }/#{ db_settings[:name] }"
      
      if input("Setup authorization DB now? Warning destructive behavior! y/n ") == "y"
        ActiveRecord::Base.establish_connection(db_settings[:url])
        ActiveRecord::Base.connection.execute("
          DROP TABLE IF EXISTS clients, user_roles, users, roles, access_tokens CASCADE;

          CREATE TABLE users(
            id serial PRIMARY KEY,
            #{ @config[:authorization][:require_username] ? 'username CHAR(255) NOT NULL,' : ''}
            #{ @config[:authorization][:require_email] ? 'email CHAR(255) NOT NULL,' : ''}
            password_digest CHAR(72) NOT NULL
          );

          CREATE TABLE roles(
            id serial PRIMARY KEY,
            name CHAR(255) NOT NULL
          );

          CREATE TABLE user_roles(
            id serial PRIMARY KEY,
            user_id INTEGER NOT NULL,
            role_id INTEGER NOT NULL
          );

          CREATE TABLE clients(
            id serial PRIMARY KEY,
            name CHAR(255) NOT NULL,
            public_key CHAR(255) NOT NULL,
            private_key CHAR(255) NOT NULL
          );
          
          CREATE TABLE access_tokens(
            id serial PRIMARY KEY,
            user_id INTEGER NOT NULL,
            token CHAR(255) NOT NULL
          );
          
          ALTER TABLE user_roles ADD FOREIGN KEY (user_id) REFERENCES users;
          ALTER TABLE user_roles ADD FOREIGN KEY (role_id) REFERENCES roles;

          ALTER TABLE access_tokens ADD FOREIGN KEY (user_id) REFERENCES users;
        
          INSERT INTO roles (name) VALUES ('admin'), ('public');
        ")
         


        puts "Authorization database configured, 'admin' and 'public' roles created"

        if input("Would you like to create an admin user (y/n)? ") == 'y'
          admin_fields = []
          admin_creds = []

          if @config[:authorization][:require_username]
            admin_fields << "username"
            admin_creds << input("Username? ")
          end

          if @config[:authorization][:require_email]
            admin_fields << "email"
            admin_creds << input("Email? ")
          end

          admin_fields << "password_digest"
          admin_creds << Password.create( input("Password? ") )
        
          ActiveRecord::Base.connection.execute("
            INSERT INTO users(#{admin_fields.join( "," )}) VALUES('#{ admin_creds.join( "','" )}')
          ")
        end

        write_config
      else
        puts "You will need to manually set up your auth DB"
      end


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

    def input(prompt="", newline=false, default=nil)
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
      File.open("#{@app_root}/config.json","w") do |f|
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
