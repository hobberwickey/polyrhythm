require "rubygems"
require "bundler"
require "active_record"

require "sinatra/base"
require "sinatra/json"
require "sinatra/cookies"

require "json"
require "yaml"

require 'dotenv'
require 'warden'

Dotenv.load!("./authorization/.env")

Bundler.require :default, "authorization_#{(ENV["RACK_ENV"] || "development")}".to_sym
ActiveRecord::Base.raise_in_transactional_callbacks = true
ActiveRecord::Base.establish_connection(ENV['DATABASE_URL'])

Dir[File.dirname(__FILE__) + "/models/*.rb"].each { |file| require file }

class Authorization < Sinatra::Base  
  helpers Sinatra::Cookies

  post "/remote_login" do
    env['warden'].authenticate!(:remote_password)
    
    client = Client.find_by(:public_key => params[:public_key])
    new_token = SecureRandom.hex(64)
    access_token = AccessToken.where( :user_id => env['warden'].user.id, :client_id => client.id ).first_or_create
    access_token.update_attribute(:token, new_token)

    status 200
    return {token: new_token}.to_json
  end

  post "/login" do
    puts "WATCHING YOU!!"
    env['warden'].authenticate!(:password)
  end

  post "/logout" do
    client = Client.find_by(:public_key => params[:public_key])
    hash = Digest::SHA1.hexdigest "#{client.private_key}#{client.public_key}"
    token = AccessToken.where(:token => params[:token], :client_id => client.id)

    puts hash
    puts params[:hash]

    if token.present? && hash == params[:hash]
      token.destroy_all
      status 200
    else
      # Not sure what the status should be here. 
      status 401
    end
  end

  post "/unauthenticated" do
    status 401
  end

  post "/remote_signup" do
    @user = User.new(params[:user])
    client = Client.find_by(:public_key => params[:public_key])
      
    if client.blank?
      status 500
    else
      @user.roles << client.role
    
      if @user.save!
        env['warden'].authenticate!(:password)
    
        client = Client.find_by(:public_key => params[:public_key])
        new_token = SecureRandom.hex(64)
        access_token = AccessToken.where( :user_id => env['warden'].user.id, :client_id => client.id ).first_or_create
        access_token.update_attribute(:token, new_token)

        status 200
        return {token: new_token}.to_json
      else 
        status 500
      end
    end
  end

  post "/signup" do
    @user = User.new(params[:user])
    @user.roles << Role.find_by(:name => "user")
  
    if @user.save!
      env['warden'].authenticate!(:password)
  
      #TODO: Better home client idenification
      client = Client.find_by(:name => "application")
      new_token = SecureRandom.hex(64)
      access_token = AccessToken.where( :user_id => env['warden'].user.id, :client_id => client.id ).first_or_create
      access_token.update_attribute(:token, new_token)

      status 200
      return {token: new_token}.to_json
    else 
      status 500
    end
    
  end

  get "/password_reset" do
    user = User.where(:email => params[:email]).first

    if user
      user.reset_password
      puts "USER TOKEN: #{user.reset_token}"
      
      # email( 
      #   user.email, 
      #   '"Password Reset" <reset@moreontap.com>', 
      #   "Password Reset", 
      #   "reset_password", 
      #   { :token => user.reset_token }
      # )

      status 200
    else
      status 500
    end
  end

  post "/password_reset" do
    if env["warden"].user.present?
      env["warden"].user.update_attributes(
        :password => params[:user][:password],
        :password_confirmation => params[:user][:password_confirmation],
        :reset_token => nil,
        :reset_expire => nil,
        :provisional => nil
      )

      status 200
    else 
      status 401
    end
  end

  post "/reset_password_login" do
    env['warden'].authenticate!(:reset_token)
    
    client = Client.find_by(:public_key => params[:public_key])
    new_token = SecureRandom.hex(64)
    access_token = AccessToken.where( :user_id => env['warden'].user.id, :client_id => client.id ).first_or_create
    access_token.update_attribute(:token, new_token)

    status 200
    return {token: new_token}.to_json
  end
end

Dir.chdir(File.dirname(__FILE__) + "/lib/") { Dir.glob("**/*.rb").map {|path| require File.expand_path(path) } }