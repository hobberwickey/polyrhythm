require 'rack-proxy'
require 'rack/cors'
require 'rack/contrib'
require 'json'
require 'warden'

require 'bundler'
require 'active_record'

require_relative './lib/polyrhythm'
require_relative './lib/api'
require_relative './lib/siren'

CONFIG = JSON.parse( File.read("./config.json"), {:symbolize_names => true})
SERVICES = CONFIG[:services]

Bundler.require :default, (ENV["RACK_ENV"] || "development").to_sym
ActiveRecord::Base.raise_in_transactional_callbacks = true

$service_map = {}

use Rack::PostBodyContentTypeParser

use Rack::Cors do
  allow do
    origins '*'
    resource '/*', :headers => :any, :methods => [:get, :post, :put, :delete, :options]
  end
end

#TODO: more flexible configuration
use Warden::Manager do |config|
  config.scope_defaults( 
    :default,
    store: false, 
    strategies: [:access_token, :password], 
    action: "#{CONFIG[:authorization][:name]}/unauthenticated"
  )
  config.failure_app = self
end

class AppProxy < Rack::Proxy
  def rewrite_env(env)
    request = Rack::Request.new(env)
    
    first_segment, path = parse_path(request.path)
    
    env["HTTP_HOST"] = SERVICES[:development][:remote][first_segment]
    env["SCRIPT_NAME"] = path 
    env
  end

  def parse_path(path)
    first_segment = "/#{path.split("/")[1]}"
    new_path = "/#{path.split('/')[2..-1].join('/')}"
    
    return first_segment, new_path
  end
end
proxy = AppProxy.new

SERVICES[:development][:local].each do |k, v|
  require_relative "./#{v}/#{v}"
  $service_map[k.to_s] = v.capitalize.constantize.new
end

SERVICES[:development][:remote].each do |k, v|
  $service_map[k] = proxy
end


run Rack::URLMap.new( $service_map )