require "polyrhythm/version"
require 'fileutils'

module Polyrhythm
  class Scaffold
    DEFAULT_SERVICES = {
      :development => {
        :local => {},
        :remote => {}
      }
    }

    def self.initialize
      @app_root = Dir.pwd
      @gem_root = File.expand_path '../..', __FILE__      
    end
    
    def self.init(name, path="/", opts={})
      services = DEFAULT_SERVICES.clone
      
      if services[:development][:local][name.to_sym].nil?  && services[:development][:remote][name.to_sym].nil?
        FileUtils::mkdir_p "#{@app_root}/#{name.downcase}"
        FileUtils::copy "#{gem_root}/lib/core/config.ru" "#{app_root}/#{name.downcase}/config.ru"
        services[:development][:local][path] = name.downcase

        File.new("#{@app_root}/services.rb", "w+"){ |f| f.write(
          "SERVICES = #{Marshal.dump(services)}"
        ) }

      else
        puts "Service named #{name} already exists" 
      end
    end
    
    def self.build_service(name, opts={})

    end

    def self.remote_service(name, opts={})

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
