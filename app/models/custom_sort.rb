class CustomSort < ApplicationRecord
  belongs_to :user

  validates :name, uniqueness: { scope: :user_id, case_sensitive: false }, allow_blank: true
  validate :criteria_include_a_field
  validate :criteria_have_unique_fields
  validate :criteria_reference_known_fields
  validate :criteria_are_unique
  validate :criteria_do_not_match_builtin

  scope :ordered, -> { order(:name) }

  # Key used to identify this sort in the dropdown and sticky preference.
  def key
    "custom-#{id}"
  end

  def order_clause
    CollectibleSearch.custom_order(criteria)
  end

  # The user's name if given, otherwise a description of the ordering.
  def display_name
    name.presence || summary
  end

  # e.g. "Type asc, title desc" — a sentence-cased description of the ordering.
  def summary
    Array(criteria).filter_map do |entry|
      field = CollectibleSearch::SORT_FIELDS[entry["field"]]
      next unless field

      "#{field[:label].downcase} #{entry["direction"]}"
    end.join(", ").upcase_first
  end

  private

  def criteria_include_a_field
    errors.add(:criteria, "needs at least one field") if Array(criteria).empty?
  end

  def criteria_have_unique_fields
    fields = Array(criteria).map { |entry| entry["field"] }
    errors.add(:criteria, "uses a field more than once") if fields.uniq.length != fields.length
  end

  def criteria_reference_known_fields
    Array(criteria).each do |entry|
      known = CollectibleSearch::SORT_FIELDS.key?(entry["field"]) &&
              CollectibleSearch::DIRECTIONS.include?(entry["direction"])
      errors.add(:criteria, "has an invalid entry") unless known
    end
  end

  # No two of a user's custom sorts may have the same ordered criteria.
  def criteria_are_unique
    return if user.nil? || criteria.blank?

    duplicate = user.custom_sorts.where.not(id: id).any? { |other| other.criteria == criteria }
    errors.add(:criteria, "matches an existing custom sort") if duplicate
  end

  # A custom sort can't just replicate a built-in ordering. Compare the ordered
  # column/direction sequence (hash == would ignore column order, but ORDER BY
  # doesn't).
  def criteria_do_not_match_builtin
    mine = order_clause.to_a
    return if mine.empty?

    if CollectibleSearch::SORTS.values.any? { |order| order.to_a == mine }
      errors.add(:criteria, "matches a built-in sort")
    end
  end
end

