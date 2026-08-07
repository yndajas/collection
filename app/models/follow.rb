class Follow < ApplicationRecord
  belongs_to :follower, class_name: "User"
  belongs_to :followed, class_name: "User"

  validates :followed_id, uniqueness: { scope: :follower_id }
  validate :follower_is_not_followed

  private

  def follower_is_not_followed
    errors.add(:followed, "cannot be yourself") if follower_id == followed_id
  end
end
