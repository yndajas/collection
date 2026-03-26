class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  before_action :ensure_2fa_setup

  private

  def ensure_2fa_setup
    return unless user_signed_in?
    return if current_user.consumed_timestep.present?
    return if devise_controller? || setup_controller?

    redirect_to two_factor_authentication_setup_path
  end

  def setup_controller?
    controller_path == 'two_factor_authentication/setup'
  end
end
