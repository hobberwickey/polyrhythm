require "rubygems"
require "bundler"

require "sinatra/base"
require "sinatra/json"
require "sinatra/cookies"

require "json"
require "yaml"

require 'warden'

class Authorization < Sinatra::Base  
  APPLICATION_CONFIG = YAML.load_file(File.dirname(__FILE__) + "/config.yml")

  class ApplicationModel < ActiveRecord::Base
    self.abstract_class = true
    establish_connection APPLICATION_CONFIG[ENV['RACK_ENV'] || 'development']['db_url']
  end

  Dir.chdir(File.dirname(__FILE__) + "/lib/") { Dir.glob("**/*.rb").map {|path| eval File.read(path) } }
  Dir[File.dirname(__FILE__) + "/models/*.rb"].each { |path| eval File.read(path) }
  
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
    env['warden'].authenticate!(:password)


    new_token = SecureRandom.hex(64)
    access_token = AccessToken.where( :user_id => env['warden'].user.id ).first
    if access_token
      access_token.update_attribute( :token, new_token)
    else 
      AccessToken.create(:user_id => env['warden'].user.id, :token => new_token)
    end

    status 200
    return {token: new_token}.to_json
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

  post "/authorize" do
    if env["warden"].authenticate?(:access_token)
      return env["warden"].user
    else
      return nil
    end
  end

  post "/remote_authorize" do
    def auth
      if request.env["HTTP_AUTHORIZATION"].present? and request.env["HTTP_CREDENTIALS"].present?
        if env["warden"].authenticate?(:access_token)
          #TODO: should do something with provisionally logged in users
          @current_user = env["warden"].user
        else
          @current_user = nil
        end
      else
        if request.env["HTTP_DEVICE_ID"].present?
          if env["warden"].authenticate?(:device_id)
            @current_user = env["warden"].user
          else
            @current_user = nil
          end
        else 
          @current_user = nil
        end
      end
    end
  end

  post "/unauthenticated" do
    status 401
    return {:error => "Authenication Required"}.to_json
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
