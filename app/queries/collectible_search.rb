# Applies a Gmail-like query string and a sort option to a collectibles
# relation. Not persisted; a plain query object.
#
# Supported query syntax (whitespace separated, values may be quoted):
#   free text            matches title, notes, author or system
#   type:video_game      restrict to a collectible type (aliases: videogame, game, book, boardgame)
#   title:zelda          title (partial match); quote multi-word values
#   notes:"co-op night"  notes (partial match)
#   system:switch        video game system (partial match)
#   author:herbert       book author (partial match)
#   label:rpg            has a label with this name
#   players:>1           playable with SOME count in the window (overlap):
#   players:2..4         >, >=, <, <=, a Lo..Hi range, or a bare number
#   min_players:<=2      the game's own min/max, e.g. "supports EVERY count in
#   max_players:>=4      2..4" is "min_players:<=2 max_players:>=4"
#   is:completed         completed collectibles (also: evergreen, multiplayer,
#                        local, online, coop, competitive)
#   -is:completed        negate any is: flag (e.g. not completed)
#   a b OR c d           OR (uppercase) unions groups of filters, e.g.
#                        "players:1 OR players:3". OR binds looser than the
#                        implicit AND, so "a b OR c" means "(a AND b) OR c".
#   a AND b              AND (uppercase) is optional: terms are already ANDed,
#                        so it's a readability no-op, dropped while parsing.
#   (a OR b) c           parentheses override precedence, e.g.
#                        "(type:book OR is:coop) an" is books-or-coop AND "an".
#
# The query string is parsed into a boolean AST by QuerySearch::Parser (in the
# shared base class); this class supplies the collectible-specific token
# mapping (#apply) and sort handling.
class CollectibleSearch < QuerySearch
  SORTS = {
    "updated" => { updated_at: :desc },
    "-updated" => { updated_at: :asc },
    "created" => { created_at: :desc },
    "-created" => { created_at: :asc },
    "title" => { title: :asc },
    "-title" => { title: :desc },
    "type" => { type: :asc, title: :asc },
    "system" => { system: :asc, title: :asc }
  }.freeze

  # Built-in options offered in the sort dropdown (key => label). Users may hide
  # any of these.
  DEFAULT_OPTIONS = {
    "updated" => "Recently updated",
    "created" => "Recently added",
    "title" => "Title A–Z",
    "-title" => "Title Z–A",
    "type" => "Type",
    "system" => "System"
  }.freeze

  # Fields the custom sort composer can order by (key => label + column).
  SORT_FIELDS = {
    "title" => { label: "Title", column: :title },
    "type" => { label: "Type", column: :type },
    "system" => { label: "System", column: :system },
    "author" => { label: "Author", column: :author },
    "completed" => { label: "Completed", column: :completed },
    "evergreen" => { label: "Evergreen", column: :evergreen },
    "created" => { label: "Date added", column: :created_at },
    "updated" => { label: "Date updated", column: :updated_at }
  }.freeze

  DIRECTIONS = %w[asc desc].freeze

  DEFAULT_SORT = "updated"

  # Turn a stored custom-sort definition (ordered [{field, direction}]) into an
  # ActiveRecord order hash, e.g. { type: :asc, title: :asc }.
  def self.custom_order(criteria)
    Array(criteria).each_with_object({}) do |entry, order|
      field = SORT_FIELDS[entry["field"] || entry[:field]]
      direction = (entry["direction"] || entry[:direction]).to_s
      next unless field && DIRECTIONS.include?(direction)

      order[field[:column]] = direction.to_sym
    end
  end

  TYPE_ALIASES = {
    "videogame" => "video_game",
    "game" => "video_game",
    "video_game" => "video_game",
    "boardgame" => "board_game",
    "board_game" => "board_game",
    "book" => "book"
  }.freeze

  IS_FLAGS = %w[completed evergreen multiplayer local online coop cooperative competitive].freeze

  attr_reader :sort

  # custom_sorts: { "custom-5" => [{ "field" =>, "direction" => }, ...], ... }
  def initialize(relation, query: nil, sort: nil, custom_sorts: {})
    super(relation, query:)
    @custom_sorts = custom_sorts || {}
    @sort = valid_sort?(sort) ? sort : DEFAULT_SORT
  end

  def results
    matches.order(order_clause).distinct
  end

  private

  def valid_sort?(sort)
    SORTS.key?(sort) || @custom_sorts.key?(sort)
  end

  def order_clause
    if @custom_sorts.key?(@sort)
      order = self.class.custom_order(@custom_sorts[@sort])
      return order if order.present?
    end

    SORTS.fetch(@sort, SORTS.fetch(DEFAULT_SORT))
  end

  def apply(scope, token)
    key = token[:key]
    value = token[:value]
    negated = token[:negated]
    return scope if value.blank?

    case key
    when nil
      match_free_text(scope, value, negated)
    when "type"
      resolved = TYPE_ALIASES[value.downcase]
      if resolved
        negated ? scope.where.not(type: resolved) : scope.where(type: resolved)
      else
        negated ? scope : scope.none
      end
    when "system"
      match_like(scope, "collectibles.system", value, negated)
    when "title"
      match_like(scope, "collectibles.title", value, negated)
    when "notes"
      match_like(scope, "collectibles.notes", value, negated)
    when "author"
      match_like(scope, "collectibles.author", value, negated)
    when "label"
      match_label(scope, value, negated)
    when "players"
      match_players(scope, value, negated)
    when "min_players"
      match_player_field(scope, "min_players", value, negated)
    when "max_players"
      match_player_field(scope, "max_players", value, negated)
    when "is"
      apply_flag(scope, value.downcase, negated:)
    else
      scope
    end
  end

  # Board-game player count, GitHub-style: players:>1 players:<5 (also >=, <=,
  # a Lo..Hi range, or a bare number). A game matches if a player count in its
  # min..max range satisfies the bound, so a lower bound (>, >=) constrains
  # max_players and an upper bound (<, <=) constrains min_players. A bare number
  # (players:4) means "supports 4" — min_players <= 4 AND max_players >= 4.
  def match_players(scope, value, negated)
    bounds = player_bounds(value)
    return scope if bounds.nil?

    if negated
      # NULL-safe NOT(A AND B) = (NOT A) OR (NOT B); non-board-games (NULL) are kept.
      clause = bounds.map { |col, op, n| "(collectibles.#{col} IS NULL OR NOT (collectibles.#{col} #{op} #{n}))" }
      scope.where(clause.join(" OR "))
    else
      clause = bounds.map { |col, op, n| "collectibles.#{col} #{op} #{n}" }
      scope.where(clause.join(" AND "))
    end
  end

  # Filter a game's own min_players / max_players column directly, so users can
  # express containment, e.g. "supports every count from 2 to 4" is
  # "min_players:<=2 max_players:>=4".
  def match_player_field(scope, column, value, negated)
    bounds = numeric_bounds(value)
    return scope if bounds.nil?

    if negated
      clause = bounds.map { |op, n| "(collectibles.#{column} IS NULL OR NOT (collectibles.#{column} #{op} #{n}))" }
      scope.where(clause.join(" OR "))
    else
      clause = bounds.map { |op, n| "collectibles.#{column} #{op} #{n}" }
      scope.where(clause.join(" AND "))
    end
  end

  # Overlap mapping for players:: a lower bound constrains max_players and an
  # upper bound constrains min_players, so a match means some count in the game's
  # range satisfies the bound. Returns [[column, sql_op, integer], ...] (ANDed).
  def player_bounds(value)
    numeric_bounds(value)&.flat_map do |op, n|
      case op
      when ">" then [ [ "max_players", ">=", n + 1 ] ]
      when ">=" then [ [ "max_players", ">=", n ] ]
      when "<" then [ [ "min_players", "<=", n - 1 ] ]
      when "<=" then [ [ "min_players", "<=", n ] ]
      else [ [ "max_players", ">=", n ], [ "min_players", "<=", n ] ] # "=" / bare number
      end
    end
  end

  # Parse a numeric filter value into [[sql_op, integer], ...] (ANDed). Handles
  # >, >=, <, <=, a Lo..Hi range, and a bare number (exact). nil if unparseable.
  # Operators are a fixed set and integers are cast, so values are safe to inline.
  def numeric_bounds(value)
    case value.strip
    when /\A(\d+)\.\.(\d+)\z/
      [ [ ">=", $1.to_i ], [ "<=", $2.to_i ] ]
    when /\A(>=|>|<=|<|=)?(\d+)\z/
      [ [ $1 || "=", $2.to_i ] ]
    end
  end

  def match_free_text(scope, value, negated)
    match_any_like(scope,
      %w[collectibles.title collectibles.notes collectibles.author collectibles.system],
      value, negated)
  end

  # Label matching uses an id subquery in both directions: a collectible can
  # have several labels, so negation means "has no label matching", not "has a
  # row that doesn't match". The subquery form (rather than a join on the base)
  # keeps this composable inside arbitrary AND/OR nesting.
  def match_label(scope, value, negated)
    matching = Collectible.joins(:labels).where("labels.name LIKE ?", "%#{value}%")
    negated ? scope.where.not(id: matching) : scope.where(id: matching)
  end

  def apply_flag(scope, flag, negated:)
    condition =
      case flag
      when "completed" then { completed: true }
      when "evergreen" then { evergreen: true }
      when "local" then { local_multiplayer: true }
      when "online" then { online_multiplayer: true }
      when "coop", "cooperative" then { cooperative: true }
      when "competitive" then { competitive: true }
      when "multiplayer"
        return scope.where(local_multiplayer: false, online_multiplayer: false) if negated
        return scope.where(local_multiplayer: true).or(scope.where(online_multiplayer: true))
      else
        return scope
      end

    negated ? scope.where.not(condition) : scope.where(condition)
  end
end
