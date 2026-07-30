class RootController < ApplicationController
  def index
    # One de-duplicated list of collections the visitor can open, each tagged
    # with how they relate to it. First tag wins, so order the sources by
    # priority: your own, then shared with you, then merely public.
    collections = {}
    remember = ->(user, relationship) { collections[user.id] ||= { user:, relationship: } }

    if user_signed_in?
      remember.call(current_user, "Your collection")
      current_user.received_accesses.includes(:owner).each do |access|
        remember.call(access.owner, "Shared with you")
      end
    end

    User.where(public_profile: true).order(updated_at: :desc).limit(50).each do |user|
      remember.call(user, "Public profile")
    end

    # Group by relationship (yours, then shared, then public), most recently
    # updated first within each group.
    rank = { "Your collection" => 0, "Shared with you" => 1, "Public profile" => 2 }
    @collections = collections.values.sort_by do |entry|
      [ rank.fetch(entry[:relationship]), -entry[:user].updated_at.to_i ]
    end
  end
end
