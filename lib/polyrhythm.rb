require "polyrhythm/version"
require 'fileutils'
require "json"
require 'erb'
require 'readline'
require 'active_support/inflector'
require "bcrypt"
require 'highline/import'

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
      
      puts ""
      puts "Building root service"
      puts ""

      root_db = {
        :adapter => "pg", #input("Root service database adpater (default 'pg') ")
        :user_name => ask("Database user:  "),
        :password => ask("Database password:  "){ |q| q.echo = "*" },
        :name => ask("Database name:  ")
      }

      build_service("application", "/", root_db)

      puts "Root service built"
      puts ""

      if input("Would you like to install the authorization service now? (y/n) ") == "y"
        puts ""
        build_auth
      else
        puts ""
        #TODO: See if another auth service should be used
        write_config
      end
    end

    def build_service(name, path, db_config)
      @name = name
      @path = path
      @db = db_config
      @db_url = "#{ DEFAULT_CONFIG[:db_roots][@db[:adapter].to_sym] }://#{ @db[:username] }#{ @db[:password] != '' ? '' : ':' }#{ @db[:password] }@localhost:#{ DEFAULT_CONFIG[:db_ports][@db[:adapter].to_sym] }/#{ @db[:name] }"
      
      dir = "#{@app_root}/#{@name.downcase}"
      FileUtils.cp_r "#{@gem_root}/lib/service/.", dir

      build_from_template "config.rb.erb", "#{dir}/config.rb"
      build_from_template "application_template.erb", "#{dir}/#{@name}.rb"
      build_from_template "helpers.erb", "#{dir}/lib/helpers.rb"
      build_from_template "gemfile.erb", "#{@app_root}/Gemfile", 'a+'
      
      #TODO: move into a gem
      build_from_template "siren.erb", "#{dir}/lib/api/siren.rb"
      build_from_template "api.erb", "#{dir}/lib/api/api.rb"

      @config[:services][:development][:local][@path] = @name.downcase
      write_config
    end

    def build_auth
      require "active_record"

      @config[:authorization][:name] = "authorization" #ask("What would you like your authorization service to be named? (default: authorization):  ")
      @config[:authorization][:require_username] = ask("Would you like to require a username for authorization? y/n  " ) == "y" ? true : false
      @config[:authorization][:require_email] = ask("Would you like to require an email for authorization? y/n  " ) == "y" ? true : false
      
      FileUtils.cp_r "#{@gem_root}/lib/authorization", "#{@app_root}/#{@config[:authorization][:name].downcase}"

      puts "Database configuration:"
      puts ""

      db_settings = @config[:authorization][:database]
      db_settings[:adapter] = "pg" #TODO: for now
      db_settings[:username] = ask("Database user?  " ) 
      db_settings[:password] = ask("Database password?  " ){ |q| q.echo = "*" } 
      db_settings[:name] = ask("Database name?  " ) 

      @db_url = "#{ DEFAULT_CONFIG[:db_roots][db_settings[:adapter].to_sym] }://#{ db_settings[:username] }#{ db_settings[:password] != '' ? '' : ':' }#{ db_settings[:password] }@localhost:#{ DEFAULT_CONFIG[:db_ports][db_settings[:adapter].to_sym] }/#{ db_settings[:name] }"
      @name = @config[:authorization][:name]
      
      build_from_template "config.rb.erb", "#{@app_root}/#{@config[:authorization][:name].downcase}/config.rb"
      
      if input("Setup authorization DB now? Warning destructive behavior! y/n ") == "y"
        ActiveRecord::Base.establish_connection(@db_url)
        ActiveRecord::Base.connection.execute("
          DROP TABLE IF EXISTS clients, user_roles, users, roles, access_tokens CASCADE;

          CREATE TABLE users(
            id serial PRIMARY KEY,
            #{ @config[:authorization][:require_username] ? 'username character varying NOT NULL,' : ''}
            #{ @config[:authorization][:require_email] ? 'email character varying NOT NULL,' : ''}
            password_digest character varying NOT NULL
          );

          CREATE TABLE roles(
            id serial PRIMARY KEY,
            name character varying NOT NULL
          );

          CREATE TABLE user_roles(
            id serial PRIMARY KEY,
            user_id INTEGER NOT NULL,
            role_id INTEGER NOT NULL
          );

          CREATE TABLE clients(
            id serial PRIMARY KEY,
            name character varying NOT NULL,
            public_key character varying NOT NULL,
            private_key character varying NOT NULL
          );
          
          CREATE TABLE access_tokens(
            id serial PRIMARY KEY,
            user_id INTEGER NOT NULL,
            token character varying NOT NULL
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
            admin_creds << ask("Username?  ")
          end

          if @config[:authorization][:require_email]
            admin_fields << "email"
            admin_creds << ask("Email?  ")
          end

          admin_fields << "password_digest"
          admin_creds << Password.create( ask("Password?  "){ |q| q.echo = "*" } )
        
          user = ActiveRecord::Base.connection.execute("
            INSERT INTO users(#{admin_fields.join( "," )}) VALUES('#{ admin_creds.join( "','" )}') RETURNING id
          ")

          ActiveRecord::Base.connection.execute("
            INSERT INTO user_roles (user_id, role_id) VALUES( '#{user[0]['id']}', (SELECT id FROM roles AS r WHERE r.name = 'admin') )
          ")

        end

        @config[:services][:development][:local]["/#{@config[:authorization][:name].downcase}"] = @config[:authorization][:name].downcase
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
