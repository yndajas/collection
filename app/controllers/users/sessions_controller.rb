class Users::SessionsController < Devise::SessionsController
  def create
    self.resource = warden.authenticate!(auth_options)

    if resource.otp_required_for_login && resource.consumed_timestep.present?
      session[:otp_user_id] = resource.id
      sign_out(resource)
      redirect_to two_factor_authentication_session_path
    else
      # Duplicates default Devise::SessionsController#create logic
      set_flash_message!(:notice, :signed_in)
      sign_in(resource_name, resource)
      respond_with resource, location: after_sign_in_path_for(resource)
    end
  end
end
