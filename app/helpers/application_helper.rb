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
end
