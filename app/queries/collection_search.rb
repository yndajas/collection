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
#   a OR b, (a b) c      OR / grouping, exactly as in the collectible search
#
# is:following, is:mine and is:shared are viewer-relative and match nothing when
# signed out. The base relation already bounds visibility; these filter within it.
class CollectionSearch < QuerySearch
  SORTS = %w[recent name].freeze
  SORT_OPTIONS = { "recent" => "Recently updated", "name" => "Name A–Z" }.freeze
  DEFAULT_SORT = "recent"

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
  # empty collections, sort last under DESC. Name falls back to username.
  def order_clause
    case @sort
    when "name" then Arel.sql("lower(coalesce(users.display_name, users.username))")
    else { collection_updated_at: :desc, id: :asc }
    end
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
    else
      scope
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
