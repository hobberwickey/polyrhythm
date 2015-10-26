require "rubygems"
require "bundler"
require "active_record"

require "sinatra/base"
require 'sinatra/flash'
require "sinatra/json"
require "sinatra/cookies"

require "json"
require "yaml"

require 'dotenv'

Dotenv.load

Bundler.require :default, (ENV["RACK_ENV"] || "development").to_sym
ActiveRecord::Base.raise_in_transactional_callbacks = true # To silence all those stupid warnings
ActiveRecord::Base.establish_connection(ENV['DATABASE_URL'])

Dir[File.dirname(__FILE__) + "/models/*.rb"].each { |file| require file }

class Application < Sinatra::Base  
  helpers Sinatra::Cookies

  get "/" do
    "Welcome to your service"
  end
end

Dir[File.dirname(__FILE__) + "/lib/*.rb"].each { |file| require file }
Dir[File.dirname(__FILE__) + "/lib/formats/*.rb"].each { |file| require file }