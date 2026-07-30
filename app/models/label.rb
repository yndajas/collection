class Label < ApplicationRecord
  belongs_to :user
  has_many :collectible_labels, dependent: :destroy
  has_many :collectibles, through: :collectible_labels

  COLOURS = %w[red orange yellow green teal blue indigo purple pink].freeze

  validates :name, presence: true, uniqueness: { scope: :user_id, case_sensitive: false }
  validates :colour, inclusion: { in: COLOURS }
  validates :collectible_types, presence: true
  validate :collectible_types_are_valid

  after_update :prune_disallowed_collectibles, if: :saved_change_to_collectible_types?

  scope :ordered, -> { order(:name) }

  # A label must opt in to each type it can be applied to.
  def applies_to_type?(type)
    collectible_types.include?(type.to_s)
  end

  # Human-readable list of the types this label applies to.
  def applicable_type_labels
    collectible_types.filter_map { |type| Collectible.model_for(type)&.type_label }
  end

  private

  def collectible_types_are_valid
    return if Array(collectible_types).all? { |type| Collectible::TYPES.include?(type) }

    errors.add(:collectible_types, "contains an unknown collectible type")
  end

  # When a type is dropped from this label, detach it from every collectible of
  # that type so the label is never left on something it no longer applies to.
  def prune_disallowed_collectibles
    previous_types, current_types = saved_change_to_collectible_types
    removed = Array(previous_types) - Array(current_types)
    return if removed.empty?

    collectible_labels.joins(:collectible)
                      .where(collectibles: { type: removed })
                      .destroy_all
  end
end
