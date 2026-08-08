module CollectiblesHelper
  # Per-type counts for a user's collection as phrases like "3 video games" or
  # "1 book", non-zero types only, in Collectible::TYPES order. Empty array for
  # an empty collection. One grouped count query per user.
  def collectible_counts(user)
    counts = user.collectibles.group(:type).count
    Collectible::TYPES.filter_map do |type|
      count = counts[type].to_i
      next if count.zero?

      "#{count} #{Collectible.model_for(type).type_label.downcase.pluralize(count)}"
    end
  end

  # A user-defined label as a tag. The background is the active theme's colour
  # for this label's palette key; text/border come from theme variables (see
  # .tag--label).
  def label_tag_span(label)
    content_tag(:span, label.name, class: "tag tag--label",
      style: "background-color: var(--label-#{label.colour});")
  end

  # Human-readable list of a collectible's boolean attributes, alphabetised,
  # e.g. ["Co-op", "Competitive", "Completed"].
  def collectible_traits(collectible)
    traits = []
    traits << "Completed" if collectible.completed?
    traits << "Evergreen" if collectible.evergreen?
    traits << "Local multiplayer" if collectible.local_multiplayer?
    traits << "Online multiplayer" if collectible.online_multiplayer?
    traits << "Co-op" if collectible.cooperative?
    traits << "Competitive" if collectible.competitive?
    traits.sort_by(&:downcase)
  end

  # A one-line summary of the type-specific facts about a collectible.
  def collectible_subtitle(collectible)
    case collectible
    when VideoGame
      collectible.system.presence
    when BoardGame
      count = collectible.player_count
      count && "#{count} players"
    when Book
      collectible.author.presence && "by #{collectible.author}"
    end
  end
end
