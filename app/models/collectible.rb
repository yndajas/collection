class Collectible < ApplicationRecord
  # Ordered catalogue of external search links. Each collectible type opts in to
  # a subset via +applicable_link_keys+; users choose which to surface via
  # +User#visible_link_keys+.
  LINK_DEFINITIONS = [
    { key: "psnprofiles", name: "PSNProfiles", url: "https://psnprofiles.com/search/games?q=%{q}" },
    { key: "psnprofiles_guides", name: "PSNProfiles guides", url: "https://psnprofiles.com/search/guides?q=%{q}" },
    { key: "psprices", name: "PSPrices", url: "https://psprices.com/region-gb/games?q=%{q}" },
    { key: "metacritic", name: "Metacritic", url: "https://www.metacritic.com/search/%{q}/" },
    { key: "opencritic", name: "OpenCritic", url: "https://opencritic.com/search?criteria=%{q}" },
    { key: "youtube", name: "YouTube", url: "https://www.youtube.com/results?search_query=%{q}" },
    { key: "steam", name: "Steam", url: "https://store.steampowered.com/search/?term=%{q}" },
    { key: "howlongtobeat", name: "HowLongToBeat", url: "https://howlongtobeat.com/?q=%{q}" },
    { key: "boardgamegeek", name: "BoardGameGeek", url: "https://boardgamegeek.com/geeksearch.php?action=search&objecttype=boardgame&q=%{q}" },
    { key: "goodreads", name: "Goodreads", url: "https://www.goodreads.com/search?q=%{q}" }
  ].freeze

  LINK_KEYS = LINK_DEFINITIONS.map { |definition| definition[:key] }.freeze

  # STI subclasses, keyed by the snake_case value stored in the +type+ column.
  TYPES = %w[video_game board_game book].freeze

  # Optional, type-specific columns. Each subclass whitelists the ones it uses
  # via +applicable_fields+; the rest must stay blank for that type.
  OPTIONAL_FIELDS = %i[
    system local_multiplayer online_multiplayer cooperative competitive
    min_players max_players author
  ].freeze

  # Touch drives the owner's "recently updated" signal. Bumping
  # +collection_updated_at+ (in addition to +updated_at+) gives a recency
  # measure that only moves on collectible changes, never on logins or settings
  # edits. Fires on create, update, and destroy.
  belongs_to :user, touch: :collection_updated_at
  has_many :collectible_labels, dependent: :destroy
  has_many :labels, through: :collectible_labels

  validates :title, presence: true
  validate :only_applicable_fields_set

  scope :ordered, -> { order(updated_at: :desc) }

  class << self
    # Store STI type as snake_case (e.g. "video_game") rather than "VideoGame".
    def sti_name
      super.underscore
    end

    def sti_class_for(type_name)
      super(type_name.to_s.camelize)
    end

    # Resolve a snake_case type param to its model class, or nil if unknown.
    def model_for(type_param)
      return nil unless TYPES.include?(type_param.to_s)

      type_param.to_s.camelize.constantize
    end

    # Human-friendly type name, e.g. "Video game".
    def type_label
      model_name.human(default: name.underscore.humanize)
    end
  end

  def type_label
    self.class.type_label
  end

  # Which link keys make sense for this collectible type.
  def applicable_link_keys
    []
  end

  # Which optional columns this collectible type uses (subclasses override).
  def applicable_fields
    []
  end

  private

  # Reject type-specific fields set on a type they don't belong to (e.g. a book
  # with a player count). Booleans count as "set" only when true.
  def only_applicable_fields_set
    (OPTIONAL_FIELDS - applicable_fields).each do |field|
      value = public_send(field)
      set = [ true, false ].include?(value) ? value == true : value.present?
      errors.add(field, "doesn't apply to #{type_label.downcase.pluralize}") if set
    end
  end

  public

  # Search links for this collectible, optionally restricted to a set of keys
  # (e.g. the owner's visible selection). Owners pass +only: nil+ to see all.
  def search_links(only: nil)
    query = CGI.escape(title.to_s)
    keys = applicable_link_keys
    keys &= only.map(&:to_s) unless only.nil?

    LINK_DEFINITIONS.select { |definition| keys.include?(definition[:key]) }.map do |definition|
      { name: definition[:name], url: format(definition[:url], q: query) }
    end.sort_by { |link| link[:name].downcase }
  end
end
