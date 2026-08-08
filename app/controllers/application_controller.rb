class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  before_action :ensure_2fa_setup

  PER_PAGE = 15

  private

  # Paginate +scope+ for the requested page. Pagination owns the page math.
  def paginate(scope, per_page: PER_PAGE)
    Pagination.new(scope, page: params[:page].to_i, per_page:)
  end

  # Which look-up link keys to show the current viewer on +profile_owner+'s
  # collection (nil means "all applicable links"). Signed-out visitors see every
  # link; a signed-in viewer sees their own kept set, and none at all on other
  # people's collections when they've opted into that.
  def viewer_link_keys(profile_owner)
    return nil unless user_signed_in?
    return [] if current_user != profile_owner && current_user.hide_links_on_others?

    current_user.visible_link_keys
  end

  def ensure_2fa_setup
    return unless user_signed_in?
    return unless current_user.otp_required_for_login
    return if current_user.consumed_timestep.present?
    return if devise_controller? || setup_controller?

    redirect_to two_factor_authentication_setup_path
  end

  def setup_controller?
    controller_path == "two_factor_authentication/setup"
  end
end
