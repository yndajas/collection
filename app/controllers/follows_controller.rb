class FollowsController < ApplicationController
  before_action :authenticate_user!

  # Follow another user's collection. You can only follow a collection you can
  # currently see, and never your own. find_or_create_by keeps a repeated
  # follow idempotent against the unique index.
  def create
    target = find_target

    if followable?(target)
      current_user.follows_given.find_or_create_by(followed: target)
      redirect_back fallback_location: profile_path(target.username),
                    notice: "You’re now following #{target.name}’s collection"
    else
      redirect_back fallback_location: root_path,
                    alert: "You can’t follow that collection"
    end
  end

  def destroy
    target = find_target
    current_user.follows_given.where(followed: target).destroy_all if target

    redirect_back fallback_location: (target ? profile_path(target.username) : root_path),
                  notice: target ? "You’ve unfollowed #{target.name}’s collection" : "Unfollowed"
  end

  private

  def find_target
    User.find_by(username: params[:username])
  end

  def followable?(target)
    target.present? && target != current_user && target.visible_to?(current_user)
  end
end
