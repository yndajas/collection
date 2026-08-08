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

      # Don't let the user hide every built-in option unless they have a custom
      # sort to fall back on, so there's always something to sort a collection by.
      if shown.empty? && @user.custom_sorts.none?
        flash.now[:alert] = "Keep at least one sort option ticked, or add a custom sort first."
        render :show, status: :unprocessable_entity
      elsif @user.save
        redirect_to settings_sorting_path, notice: "Sort options updated."
      else
        render :show, status: :unprocessable_entity
      end
    end
  end
end
