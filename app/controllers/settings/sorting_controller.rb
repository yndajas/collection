module Settings
  class SortingController < ApplicationController
    before_action :authenticate_user!

    def show
      @user = current_user
    end

    def update
      @user = current_user
      # The checkboxes list the options to SHOW; hide whatever isn't ticked.
      shown = Array(params.dig(:user, :shown_default_sorts)) & CollectibleSearch::DEFAULT_OPTIONS.keys
      @user.hidden_default_sorts = CollectibleSearch::DEFAULT_OPTIONS.keys - shown

      if @user.save
        redirect_to settings_sorting_path, notice: "Sort options updated."
      else
        render :show, status: :unprocessable_entity
      end
    end
  end
end
