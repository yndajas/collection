class CollectionsController < ApplicationController
  # A collection is a user's profile. This lists every collection the viewer is
  # allowed to see, searched and sorted with the same Gmail-like query DSL as a
  # single collection's contents (see CollectionSearch).
  def index
    @search = CollectionSearch.new(
      User.visible_to_viewer(current_user),
      query: params[:q],
      sort: params[:sort],
      viewer: current_user
    )
    @collections = @search.results
  end
end
