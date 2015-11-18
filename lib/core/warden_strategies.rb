require "warden"

Warden::Manager.before_failure do |env,opts|
  env['REQUEST_METHOD'] = 'POST'
end

Warden::Strategies.add(:access_token) do
  def valid?
    request.env["HTTP_AUTHORIZATION"].present? and request.env["HTTP_CREDENTIALS"].present?
  end

  def authenticate!
    token = AccessToken.find_by(:token => request.env["HTTP_CREDENTIALS"])
    unless token.blank?
      success!(token.user)
    else 
      puts "No Auth token"
      fail!
    end
  end
end

Warden::Strategies.add(:remote_access_token) do
  def valid?
    request.env["HTTP_AUTHORIZATION"].present? and request.env["HTTP_CREDENTIALS"].present?
  end

  def authenticate!
    client = Client.find_by(:public_key => request.env["HTTP_AUTHORIZATION"])
    unless client.blank?
      token = AccessToken.find_by(:token => request.env["HTTP_CREDENTIALS"])
      unless token.blank?
        if token.client_id == client.id
          success!(token.user)
        else
          puts "Client / Auth token don't match"
          fail!
        end
      else 
        puts "No Auth token"
        fail!
      end
    else
      puts "Couldn't find client"
      fail!
    end
  end
end

Warden::Strategies.add(:remote_password) do
  def valid?
    params["user"]['username'] && params["user"]['password']
  end

  def authenticate!
    client = Client.find_by(:public_key => params['public_key'])
    if client.blank?
      puts "No Client"
      fail!
    else 
      hash = Digest::SHA1.hexdigest "#{client.private_key}#{client.public_key}"
      if hash == params['hash']
        user = User.find_by(:username => params["user"]['username'])
        
        if user and user.authenticate(params["user"]['password'])
          if user.roles.where(:id => client.role.id).exists?
            success!(user)
          else 
            fail!
          end
        else
          fail! 
        end
      else
        fail!
      end
    end
  end
end

Warden::Strategies.add(:password) do
  def valid?
    params["user"]['username'] && params["user"]['password']
  end

  def authenticate!   
    user = User.find_by(:username => params["user"]['username'])
    
    if user and user.authenticate(params["user"]['password'])
      success!(user)
    else
      fail! 
    end
  end
end

Warden::Strategies.add(:reset_token) do
  def valid?
    params["reset_token"].present? && params["public_key"].present?
  end
  
  #TODO: make sure user has access to client
  def authenticate!
    client = Client.find_by(:public_key => params["public_key"])
    unless client.blank?
      user = User.where(["reset_token = ? AND reset_expire > ?", params["reset_token"], Time.now]).first
      if user.present?
        success!(user)
      else 
        puts "Couldn't find reset token or reset token has expired"
        fail!
      end
    else
      puts "Couldn't find client"
      fail!
    end
  end
end