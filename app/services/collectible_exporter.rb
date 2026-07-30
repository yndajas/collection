require "csv"

# Serialises a collection of collectibles to CSV or JSON. Not persisted; a
# plain query/serialisation object.
class CollectibleExporter
  CSV_HEADERS = [
    "Type", "Title", "System", "Author", "Min players", "Max players",
    "Completed", "Evergreen", "Local multiplayer", "Online multiplayer",
    "Co-operative", "Competitive", "Labels", "Notes", "Created at", "Updated at"
  ].freeze

  def initialize(collectibles)
    @collectibles = collectibles
  end

  def to_csv
    CSV.generate do |csv|
      csv << CSV_HEADERS
      @collectibles.each do |collectible|
        csv << [
          collectible.type,
          collectible.title,
          collectible.system,
          collectible.author,
          collectible.min_players,
          collectible.max_players,
          collectible.completed,
          collectible.evergreen,
          collectible.local_multiplayer,
          collectible.online_multiplayer,
          collectible.cooperative,
          collectible.competitive,
          collectible.labels.map(&:name).join(", "),
          collectible.notes,
          collectible.created_at.iso8601,
          collectible.updated_at.iso8601
        ]
      end
    end
  end

  # Array of hashes, each carrying the common fields plus the type-specific ones.
  def as_data
    @collectibles.map do |collectible|
      common(collectible).merge(type_specific(collectible))
    end
  end

  private

  def common(collectible)
    {
      type: collectible.type,
      title: collectible.title,
      completed: collectible.completed,
      evergreen: collectible.evergreen,
      labels: collectible.labels.map(&:name),
      notes: collectible.notes,
      created_at: collectible.created_at.iso8601,
      updated_at: collectible.updated_at.iso8601
    }
  end

  def type_specific(collectible)
    case collectible
    when VideoGame
      {
        system: collectible.system,
        local_multiplayer: collectible.local_multiplayer,
        online_multiplayer: collectible.online_multiplayer,
        cooperative: collectible.cooperative,
        competitive: collectible.competitive
      }
    when BoardGame
      {
        min_players: collectible.min_players,
        max_players: collectible.max_players,
        cooperative: collectible.cooperative,
        competitive: collectible.competitive
      }
    when Book
      { author: collectible.author }
    else
      {}
    end
  end
end
