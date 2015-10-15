require "polyrhythm/version"

module Polyrhythm
  class Setup
    def self.scaffold
      create_server
      create_client
      create_auth
    end

    def self.create_server

    end

    def self.create_client

    end

    def self.create_auth

    end

    def self.create_model(name)
      puts Dir.pwd
    end

    def self.create_migration(name)
      puts "NAME: #{name.capitalize}"
    end
  end
end
