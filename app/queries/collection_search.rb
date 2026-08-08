# Applies a Gmail-like query string and a sort option to a relation of users
# (each user being a collection). Shares the grammar and AND/OR/negation
# evaluation with CollectibleSearch via QuerySearch.
#
# Supported query syntax (whitespace separated, values may be quoted):
#   free text            matches username or display name
#   username:ynda        username (partial match)
#   display_name:"..."   display name (partial match); alias: name:
#   is:following         collections the viewer follows
#   is:mine              the viewer's own collection
#   is:public            public collections (negate with -is:public for private)
#   is:shared            private collections shared with the viewer
#   has:books            collections holding at least one of a type (also
#                        video_games, board_games; singular/aliases accepted)
#   video_games:>5       filter by a type's count: >, >=, <, <=, a 2..4 range, or
#   books:2..4           a bare number. e.g. board_games:>=1
#   a OR b, (a b) c      OR / grouping, exactly as in the collectible search
#
# Sort options (SORT_OPTIONS) add "Most video games / board games / books"
# alongside recent and name.
#
# is:following, is:mine and is:shared are viewer-relative and match nothing when
# signed out. The base relation already bounds visibility; these filter within it.
class CollectionSearch < QuerySearch
  # Sort key => dropdown label.
  SORT_OPTIONS = {
    "recent" => "Recently updated",
    "name" => "Name A–Z",
    "video_games" => "Most video games",
    "board_games" => "Most board games",
    "books" => "Most books"
  }.freeze
  SORTS = SORT_OPTIONS.keys.freeze
  DEFAULT_SORT = "recent"

  # The "most <type>" sorts mapped to the collectible STI type they count.
  COUNT_SORTS = { "video_games" => "video_game", "board_games" => "board_game", "books" => "book" }.freeze

  attr_reader :sort

  def initialize(relation, query: nil, sort: nil, viewer: nil)
    super(relation, query:)
    @viewer = viewer
    @sort = SORTS.include?(sort.to_s) ? sort.to_s : DEFAULT_SORT
  end

  def results
    matches.order(order_clause).distinct
  end

  private

  # Recency uses collection_updated_at (a content-only signal); NULLs, i.e.
  # empty collections, sort last under DESC. Name falls back to username. The
  # "most <type>" sorts order by a per-type count.
  def order_clause
    return count_order(COUNT_SORTS[@sort]) if COUNT_SORTS.key?(@sort)

    case @sort
    when "name" then Arel.sql("lower(coalesce(users.display_name, users.username))")
    else { collection_updated_at: :desc, id: :asc }
    end
  end

  # Order by how many collectibles of +type+ each collection has, most first.
  # The correlated subquery is safe: +type+ is a fixed, whitelisted value.
  def count_order(type)
    Arel.sql(<<~SQL.squish)
      (SELECT COUNT(*) FROM collectibles
       WHERE collectibles.user_id = users.id AND collectibles.type = '#{type}') DESC,
      users.id ASC
    SQL
  end

  def apply(scope, token)
    key = token[:key]
    value = token[:value]
    negated = token[:negated]
    return scope if value.blank?

    case key
    when nil
      match_any_like(scope, %w[users.username users.display_name], value, negated)
    when "username"
      match_like(scope, "users.username", value, negated)
    when "display_name", "name"
      match_like(scope, "users.display_name", value, negated)
    when "is"
      apply_flag(scope, value.downcase, negated)
    when "has"
      match_has_type(scope, value, negated)
    else
      match_type_count(scope, key, value, negated)
    end
  end

  # Relationship / visibility flags. Each resolves to a matching subset; negation
  # excludes that subset via an id subquery, so it composes inside AND/OR nesting.
  def apply_flag(scope, flag, negated)
    matching =
      case flag
      when "following" then scope.where(id: followed_ids)
      when "mine" then scope.where(id: own_ids)
      when "public" then scope.where(public_profile: true)
      when "shared" then scope.where(public_profile: false).where(id: shared_owner_ids)
      else return scope
      end

    negated ? scope.where.not(id: matching) : scope.where(id: matching)
  end

  # has:<type> -> collections holding at least one collectible of that type.
  def match_has_type(scope, value, negated)
    type = resolve_count_type(value)
    return scope unless type

    owners = Collectible.where(type: type).select(:user_id)
    negated ? scope.where.not(id: owners) : scope.where(id: owners)
  end

  # <type>:<bounds> -> collections whose count of that type satisfies the bounds,
  # e.g. video_games:>5, books:2..4. Unknown key or unparseable bounds: no-op.
  def match_type_count(scope, key, value, negated)
    type = resolve_count_type(key)
    bounds = type && numeric_bounds(value)
    return scope unless bounds

    having = bounds.map { |op, n| "COUNT(*) #{op} #{n}" }.join(" AND ")
    owners = Collectible.where(type: type).group(:user_id).having(having).select(:user_id)
    negated ? scope.where.not(id: owners) : scope.where(id: owners)
  end

  # Resolve a type word (singular/plural or alias) to a collectible STI type.
  def resolve_count_type(word)
    CollectibleSearch::TYPE_ALIASES[word.to_s.downcase.singularize]
  end

  def followed_ids
    return User.none if @viewer.nil?

    @viewer.followed_collections.select(:id)
  end

  def own_ids
    return User.none if @viewer.nil?

    User.where(id: @viewer.id).select(:id)
  end

  def shared_owner_ids
    return User.none if @viewer.nil?

    ProfileAccess.where(viewer_id: @viewer.id).select(:owner_id)
  end
end
