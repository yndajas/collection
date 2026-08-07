class QuerySearch
  # Parses a Gmail-like query string into a boolean AST, independent of any
  # database or schema. AND is implicit (adjacent terms), OR (uppercase) binds
  # looser, and parentheses override precedence. The tree is made of:
  #
  #   [:and, [node, ...]]                     every child must match
  #   [:or,  [node, ...]]                     any child matches
  #   [:token, { negated:, key:, value: }]    a single filter; key is nil for
  #                                           free text, negated for a "-" prefix
  #
  # A QuerySearch subclass turns this tree into an ActiveRecord relation; the
  # parser itself knows nothing about which keys are valid.
  class Parser
    def self.call(query)
      new(query).call
    end

    def initialize(query)
      @lexemes = lex(query.to_s)
      @pos = 0
    end

    def call
      simplify(parse_or)
    end

    private

    # Collapse the redundant single-child :and wrappers that parenthesised
    # sub-expressions produce, so the tree is canonical (e.g. a lone token is
    # [:token, ..] rather than [:and, [[:token, ..]]]).
    def simplify(node)
      return node if node.first == :token

      children = node.last.map { |child| simplify(child) }
      node.first == :and && children.one? ? children.first : [ node.first, children ]
    end

    # Split on whitespace but keep quoted phrases (incl. key:"two words") intact.
    def scan(string)
      string.scan(/-?(?:\w+:)?"[^"]*"|\S+/)
    end

    # Turn raw whitespace-separated chunks into a flat stream of :lparen /
    # :rparen / :or markers and token hashes, peeling parentheses off bare tokens.
    # Uppercase AND is recognised but emitted as nothing: AND is already implicit
    # between adjacent terms, so this just stops it being read as free text.
    def lex(string)
      scan(string).flat_map do |raw|
        case raw
        when "OR" then [ :or ]
        when "AND" then []
        else split_parens(raw)
        end
      end
    end

    # Split leading "(" and trailing ")" off a raw token into paren markers.
    # Quoted tokens are left intact so a ")" inside a value isn't mistaken for a
    # group delimiter.
    def split_parens(raw)
      return [ parse_token(raw) ] if raw.include?('"')

      leading = raw[/\A\(+/].to_s.length
      trailing = raw[/\)+\z/].to_s.length
      core = raw.sub(/\A\(+/, "").sub(/\)+\z/, "")
      [ *([ :lparen ] * leading),
        *(core.empty? ? [] : [ parse_token(core) ]),
        *([ :rparen ] * trailing) ]
    end

    # { negated:, key:, value: } — key is nil for free text.
    def parse_token(raw)
      negated = raw.start_with?("-")
      raw = raw[1..] if negated
      key, value = raw.split(":", 2)
      if value.nil?
        { negated:, key: nil, value: key }
      else
        { negated:, key: key.downcase, value: value.delete_prefix('"').delete_suffix('"') }
      end
    end

    def parse_or
      groups = [ parse_and ]
      while @lexemes[@pos] == :or
        @pos += 1
        groups << parse_and
      end
      groups.reject! { |group| group == [ :and, [] ] } # drop leading/trailing/empty ORs
      case groups.length
      when 0 then [ :and, [] ]
      when 1 then groups.first
      else [ :or, groups ]
      end
    end

    def parse_and
      terms = []
      until (marker = @lexemes[@pos]).nil? || marker == :or || marker == :rparen
        term = parse_term
        terms << term unless term == [ :and, [] ] # empty group contributes nothing
      end
      [ :and, terms ]
    end

    def parse_term
      if @lexemes[@pos] == :lparen
        @pos += 1
        node = parse_or
        @pos += 1 if @lexemes[@pos] == :rparen
        node
      else
        token = @lexemes[@pos]
        @pos += 1
        [ :token, token ]
      end
    end
  end
end
