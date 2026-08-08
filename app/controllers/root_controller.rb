class RootController < ApplicationController
  RECENT_LIMIT = 10

  def index
    # Recently updated collections the visitor can see. collection_updated_at is
    # a content-only signal (see Collectible#touch), and NULL means an empty
    # collection, so those are excluded rather than shown as "recently updated".
    @recent = User.visible_to_viewer(current_user)
                  .where.not(collection_updated_at: nil)
                  .order(collection_updated_at: :desc)
                  .limit(RECENT_LIMIT)

    return unless user_signed_in?

    # A couple of highlights from your own collection: the newest collectible
    # and a random other one (excluded from the newest so they differ; nil when
    # you have fewer than two items). RANDOM() shuffles in the database and
    # returns one row rather than loading the whole collection to pick in Ruby.
    own = current_user.collectibles
    @newest_collectible = own.order(created_at: :desc).first
    @random_collectible = own.where.not(id: @newest_collectible).order(Arel.sql("RANDOM()")).first
    @link_keys = viewer_link_keys(current_user)

    # Collections you follow (only those you can still see), and private
    # collections shared with you. These can overlap each other and @recent.
    @followed = User.visible_to_viewer(current_user)
                    .where(id: current_user.followed_collections)
                    .order(collection_updated_at: :desc)

    @shared = User.where(public_profile: false)
                  .where(id: current_user.received_accesses.select(:owner_id))
                  .order(collection_updated_at: :desc)
  end
end
