class CollectionsController < ApplicationController
  # A collection is a user's profile. This lists every collection the viewer is
  # allowed to see, searched and sorted with the same Gmail-like query DSL as a
  # single collection's contents (see CollectionSearch).
  def index
    sort = params[:sort].presence_in(CollectionSearch::SORTS)
    remember_collections_sort(sort) if user_signed_in?

    @search = CollectionSearch.new(
      User.visible_to_viewer(current_user),
      query: params[:q],
      sort: sort || current_user&.collections_sort,
      viewer: current_user
    )
    @pagination = paginate(@search.results)
    @collections = @pagination.records
  end

  private

  # Persist the signed-in viewer's chosen list sort so it sticks across visits.
  # update_columns skips validation (sort is already whitelisted) and avoids
  # bumping updated_at / collection_updated_at.
  def remember_collections_sort(sort)
    return unless sort && sort != current_user.collections_sort

    current_user.update_columns(collections_sort: sort)
  end
end
