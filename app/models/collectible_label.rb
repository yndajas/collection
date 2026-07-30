class CollectibleLabel < ApplicationRecord
  belongs_to :collectible
  belongs_to :label

  validates :label_id, uniqueness: { scope: :collectible_id }
end
