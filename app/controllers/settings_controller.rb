class SettingsController < ApplicationController
  before_action :authenticate_user!

  # Profile settings (display name, username, visibility, external links).
  def show
    @user = current_user
  end

  def update
    @user = current_user

    if @user.update(settings_params)
      redirect_to settings_path, notice: "Settings updated."
    else
      render :show, status: :unprocessable_entity
    end
  end

  private

  def settings_params
    permitted = params.require(:user).permit(
      :username, :display_name, :theme, :hide_links_on_others, shown_link_keys: []
    )
    # The form lists the links to *show* (checked); store the complement as the
    # viewer's hidden set so an empty default means "see everything".
    shown = Array(permitted.delete(:shown_link_keys)) & Collectible::LINK_KEYS
    permitted[:hidden_link_keys] = Collectible::LINK_KEYS - shown
    permitted
  end
end
