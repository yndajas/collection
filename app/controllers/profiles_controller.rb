class ProfilesController < ApplicationController
  # Public/shared profiles are viewable without signing in. This is the single
  # collection view: owners see the same page with extra controls.
  def show
    @user = User.find_by!(username: params[:username])
    @token = params[:token]

    unless @user.visible_to?(current_user, token: @token)
      # Remember where the visitor was headed so signing in brings them back.
      store_location_for(:user, request.fullpath) unless user_signed_in?
      render :private_profile, status: :forbidden
      return
    end

    @owner = current_user == @user

    # View/sort is a per-viewer preference. An explicit choice wins; otherwise
    # fall back to the signed-in viewer's remembered preference (or the defaults
    # when logged out). A signed-in viewer's new choice is remembered against
    # them, so it follows them across every collection they browse and never
    # affects what other people see.
    custom_orders = current_user&.custom_sort_orders || {}
    valid_sorts = CollectibleSearch::SORTS.keys + custom_orders.keys
    view = params[:view].presence_in(User::COLLECTION_VIEWS)
    sort = params[:sort].presence_in(valid_sorts)
    remember_collection_preferences(view, sort) if user_signed_in?

    @view = view || current_user&.collection_view || "cards"
    @sort_options = current_user&.sort_options ||
                    CollectibleSearch::DEFAULT_OPTIONS.map { |key, label| [ label, key ] }
    @search = CollectibleSearch.new(@user.collectibles,
                                    query: params[:q],
                                    sort: sort || current_user&.collectibles_sort || "updated",
                                    custom_sorts: custom_orders)
    collectibles = @search.results.includes(:labels)
    @link_keys = viewer_link_keys(@user)

    respond_to do |format|
      # Paginate the HTML view only; the CSV/JSON exports return the full set.
      format.html do
        @pagination = paginate(collectibles)
        @collectibles = @pagination.records
      end
      format.csv do
        send_data CollectibleExporter.new(collectibles).to_csv,
                  filename: "#{@user.username}-collection-#{Date.current.iso8601}.csv",
                  type: "text/csv"
      end
      format.json do
        render json: CollectibleExporter.new(collectibles).as_data
      end
    end
  end

  private

  # Persist the signed-in viewer's latest sort/view as their preference. Uses
  # update_columns so it skips validations (values are already whitelisted) and,
  # crucially, doesn't touch updated_at (which drives "recently updated").
  def remember_collection_preferences(view, sort)
    changes = {}
    changes[:collection_view] = view if view && view != current_user.collection_view
    changes[:collectibles_sort] = sort if sort && sort != current_user.collectibles_sort
    current_user.update_columns(changes) if changes.any?
  end
end
