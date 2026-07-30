module Settings
  class ProfileAccessesController < ApplicationController
    before_action :authenticate_user!

    def create
      viewer = User.find_by("LOWER(email) = ? OR username = ?",
                            params[:identifier].to_s.downcase.strip,
                            params[:identifier].to_s.downcase.strip)

      if viewer.nil?
        redirect_to settings_visibility_path, alert: "No user found with that email or username."
        return
      end

      access = current_user.granted_accesses.build(viewer: viewer)

      if access.save
        redirect_to settings_visibility_path, notice: "#{viewer.name} can now view your collection."
      else
        redirect_to settings_visibility_path, alert: access.errors.full_messages.to_sentence
      end
    end

    def destroy
      current_user.granted_accesses.find(params[:id]).destroy!
      redirect_to settings_visibility_path, notice: "Access removed."
    end
  end
end
