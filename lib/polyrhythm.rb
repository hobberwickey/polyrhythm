require "polyrhythm/version"

module Polyrhythm
  class Setup
    def self.scaffold
      create_server
      create_client
      create_auth
    end

    def self.create_server
      app_root = Dir.pwd
      gem_root = File.expand_path '../..', __FILE__

      FileUtils.cp_r "#{gem_root}/lib/server/.", app_root
    end

    def self.create_client
      app_root = Dir.pwd
      gem_root = File.expand_path '../..', __FILE__

      FileUtils.cp_r "#{gem_root}/lib/client/.", app_root
    end

    def self.create_auth
      app_root = Dir.pwd
      gem_root = File.expand_path '../..', __FILE__

      FileUtils.cp_r "#{gem_root}/lib/authorization/.", app_root
    end

    def self.create_model(name)
      puts Dir.pwd
    end

    def self.create_migration(name)
      puts "NAME: #{name.capitalize}"
    end
  end
end
