require 'rack-proxy'
require 'rack/contrib'
require 'warden'

require './services'

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
    action: '/authorization/unauthenticated'
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

service_map = {}
SERVICES[:development][:local].each do |k, v|
  require_relative "./#{v}/#{v}"
  service_map[k] = v.capitalize.constantize.new
end

SERVICES[:development][:remote].each do |k, v|
  service_map[k] = proxy
end


run Rack::URLMap.new( service_map )