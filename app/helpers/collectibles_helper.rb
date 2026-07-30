module CollectiblesHelper
  # A small label pill. The background is the active theme's colour for this
  # label's palette key; text/border come from theme variables (see .pill).
  def label_pill(label)
    content_tag(:span, label.name, class: "pill",
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
