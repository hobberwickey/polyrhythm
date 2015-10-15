require "rubygems"
require "bundler"
require "active_record"

require "sinatra/base"
require 'sinatra/flash'
require 'sinatra/reloader'
require 'sinatra/content_for'
require "sinatra/json"
require "sinatra/cookies"

require "json"
require "yaml"

require 'dotenv'

Dotenv.load
Bundler.require :default, (ENV["RACK_ENV"] || "development").to_sym
Dir[File.dirname(__FILE__) + "/models/*.rb"].each { |file| require file }

DB_CONFIG = YAML::load(File.open('config/database.yml'))
ActiveRecord::Base.establish_connection( DB_CONFIG[(ENV["RACK_ENV"] || "development")] )

class Application < Sinatra::Base  
  helpers Sinatra::Cookies
    
  configure :development do
    register Sinatra::Reloader
  end

  before /^(?!\/(login|signup))/ do
    #uncomment to require login

    # unless session[:token].present? && session[:token] == cookies[:token]
    #   redirect "/login"
    # end
  end

  get "/" do
    erb :index
  end

  get "/forms" do
    erb :"polyrhythm-form/index"
  end

  get "/paper-forms" do
    erb :"polyrhythm-paper-form/index"
  end

  post "/show_params" do
    puts "PARAMS: #{params}"

    status 200
  end
end

require File.dirname(__FILE__) + '/config/settings.rb'
Dir[File.dirname(__FILE__) + "/lib/*.rb"].each { |file| require file }
Dir[File.dirname(__FILE__) + "/lib/formats/*.rb"].each { |file| require file }