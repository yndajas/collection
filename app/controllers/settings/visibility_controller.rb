module Settings
  class VisibilityController < ApplicationController
    before_action :authenticate_user!

    def show
      @user = current_user
      @accesses = current_user.granted_accesses.includes(:viewer)
      @share_links = current_user.share_links.order(created_at: :desc)
    end

    def update
      if current_user.update(public_profile: params.dig(:user, :public_profile))
        redirect_to settings_visibility_path, notice: "Visibility settings updated."
      else
        redirect_to settings_visibility_path, alert: current_user.errors.full_messages.to_sentence
      end
    end
  end
end
