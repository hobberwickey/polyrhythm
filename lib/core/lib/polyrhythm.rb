class Polyrhythm
  def self.auth(request, roles=[])
    request.env['warden'].authenticate!(:access_token)
    user = request.env['warden'].user  
    
    unless user.blank?
      return (roles & user.roles.pluck(:name)).length > 0
    else 
      return false
    end
  end
end