module ApplicationHelper
  # IDs of the collections the signed-in viewer follows, loaded once per request
  # so list rows can show a "following" decoration without an N+1 query.
  def followed_collection_ids
    return @followed_collection_ids if defined?(@followed_collection_ids)

    @followed_collection_ids =
      user_signed_in? ? current_user.followed_collections.ids.to_set : Set.new
  end

  # Whether the signed-in viewer follows +user+'s collection.
  def following_collection?(user)
    followed_collection_ids.include?(user.id)
  end

  # IDs of collections shared directly with the signed-in viewer (private ones
  # they've been granted access to), loaded once per request.
  def shared_collection_ids
    return @shared_collection_ids if defined?(@shared_collection_ids)

    @shared_collection_ids =
      user_signed_in? ? current_user.received_accesses.pluck(:owner_id).to_set : Set.new
  end

  # A short relationship label for a collection relative to the viewer, or nil
  # for a plain public collection. Public collections are the default and get no
  # tag; only "yours" and "shared with you" are called out.
  def collection_relationship(user)
    return "Your collection" if user_signed_in? && user == current_user
    return "Shared with you" if shared_collection_ids.include?(user.id)

    nil
  end

  # Decoration tags for a collection row: the relationship (if any) plus a
  # "following" marker. Kept in one place so callers just decide whether to show
  # tags, not which exist. All are plain neutral tags; brand colours are
  # reserved for calls to action. Empty when there's nothing to call out.
  def collection_tags(user)
    tags = []
    if (relationship = collection_relationship(user))
      tags << relationship
    end
    tags << "★ Following" if following_collection?(user)
    tags
  end

  # The current URL with +page+ applied, preserving the existing query params
  # (search, sort, view, token) so paging keeps the current filters.
  def page_url(page)
    "#{request.path}?#{request.query_parameters.merge(page: page).to_query}"
  end
end
