# Base for Gmail-like query searches. A subclass supplies +apply+ (mapping one
# parsed token to a filtered relation) plus its own ordering; this class parses
# the query string into a boolean AST (QuerySearch::Parser) and evaluates the
# AND / OR / negation structure generically, so the grammar lives in one place
# and works against any model.
class QuerySearch
  attr_reader :query

  def initialize(relation, query: nil)
    @relation = relation
    @query = query.to_s
  end

  private

  # Rows matching the query, unordered. Subclasses wrap this to add ordering.
  def matches
    evaluate(Parser.call(@query), @relation)
  end

  # Turn a parsed AST (see Parser) into matching rows. AND intersects via id
  # subqueries; OR unions via .or on structurally identical id-subquery
  # relations, so .or stays compatible however the branches differ.
  def evaluate(node, base)
    case node.first
    when :token
      apply(base, node.last)
    when :and
      node.last.reduce(base) { |acc, child| acc.where(id: evaluate(child, base)) }
    when :or
      node.last
        .map { |child| base.where(id: evaluate(child, base)) }
        .reduce { |a, b| a.or(b) }
    end
  end

  # Map a single token { key:, value:, negated: } to a filtered relation.
  # Subclasses must implement this.
  def apply(scope, token)
    raise NotImplementedError, "#{self.class} must implement #apply"
  end

  # Case-insensitive LIKE on a single column. Negation is NULL-safe: a row whose
  # column is NULL genuinely doesn't contain the value, so it's kept.
  def match_like(scope, column, value, negated)
    like = "%#{value}%"
    if negated
      scope.where("#{column} IS NULL OR #{column} NOT LIKE ?", like)
    else
      scope.where("#{column} LIKE ?", like)
    end
  end

  # Case-insensitive LIKE of +value+ against any of +columns+ (matches when any
  # column contains it). Negation is NULL-safe and requires every column to not
  # contain the value. Subclasses use this for their free-text (unqualified)
  # search over a handful of columns.
  def match_any_like(scope, columns, value, negated)
    like = "%#{value}%"
    if negated
      clause = columns.map { |column| "(#{column} IS NULL OR #{column} NOT LIKE :q)" }.join(" AND ")
      scope.where(clause, q: like)
    else
      clause = columns.map { |column| "#{column} LIKE :q" }.join(" OR ")
      scope.where(clause, q: like)
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
end
