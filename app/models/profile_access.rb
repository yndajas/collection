class ProfileAccess < ApplicationRecord
  belongs_to :owner, class_name: "User"
  belongs_to :viewer, class_name: "User"

  validates :viewer_id, uniqueness: { scope: :owner_id }
  validate :owner_is_not_viewer

  private

  def owner_is_not_viewer
    errors.add(:viewer, "cannot be yourself") if owner_id == viewer_id
  end
end
