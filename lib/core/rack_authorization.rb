require 'warden_strategies'

class RackAuthorization
  def self.has_access(roles, request)
    return true
  end
end