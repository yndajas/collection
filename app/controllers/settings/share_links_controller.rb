module Settings
  class ShareLinksController < ApplicationController
    before_action :authenticate_user!

    EXPIRY_OPTIONS = {
      "never" => nil,
      "1 hour" => 1.hour,
      "1 day" => 1.day,
      "1 week" => 1.week,
      "1 month" => 1.month
    }.freeze

    def create
      share_link = current_user.share_links.build(description: params[:description])
      duration = EXPIRY_OPTIONS[params[:expires_in]]
      share_link.expires_at = duration ? Time.current + duration : nil

      if share_link.save
        redirect_to settings_visibility_path, notice: "Share link created."
      else
        redirect_to settings_visibility_path, alert: share_link.errors.full_messages.to_sentence
      end
    end

    def destroy
      current_user.share_links.find(params[:id]).destroy!
      redirect_to settings_visibility_path, notice: "Share link revoked."
    end
  end
end
