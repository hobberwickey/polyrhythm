helpers do
  def current_user
    return unless session[:user_id]
    @current_user ||= User.find(session[:user_id])
  end

  def siren(obj = nil)
    return '{}' if obj.nil?
    msg = obj.is_a?(ActiveRecord::Relation) ? 'relation' : 'instance'
    Siren.send(:"#{msg}_to_siren", obj, request, @current_user)
  end
end
