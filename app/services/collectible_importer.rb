require "csv"
require "json"

# Parses pasted or uploaded text into an array of collectible attribute hashes
# ready to hand to the import review step. Supports three formats:
#
#   :titles  one title per line, all of +default_type+
#   :csv     the columns produced by CollectibleExporter (headers required)
#   :json    the objects produced by CollectibleExporter#as_data
#
# Label names are resolved against the user's existing labels; unknown names
# are ignored (and reported via #unknown_labels).
class CollectibleImporter
  TYPE_ALIASES = {
    "video_game" => "video_game", "videogame" => "video_game", "game" => "video_game",
    "board_game" => "board_game", "boardgame" => "board_game",
    "book" => "book"
  }.freeze

  # Normalised header/key => attribute.
  KEY_MAP = {
    "type" => :type, "title" => :title, "system" => :system, "author" => :author,
    "min_players" => :min_players, "max_players" => :max_players,
    "completed" => :completed, "evergreen" => :evergreen,
    "local_multiplayer" => :local_multiplayer, "online_multiplayer" => :online_multiplayer,
    "cooperative" => :cooperative, "co_operative" => :cooperative,
    "competitive" => :competitive, "labels" => :labels, "notes" => :notes
  }.freeze

  BOOLEAN_ATTRS = %i[completed evergreen local_multiplayer online_multiplayer cooperative competitive].freeze
  TRUTHY = %w[true 1 yes y t].freeze

  attr_reader :unknown_labels

  def initialize(content, format:, default_type: "video_game", user:)
    @content = content.to_s
    @format = format.to_sym
    @default_type = default_type
    @user = user
    @unknown_labels = []
  end

  # Array of attribute hashes (symbol keys), each with a resolved :type and
  # :label_ids. Rows without a title are dropped.
  def rows
    parsed =
      case @format
      when :csv then parse_csv
      when :json then parse_json
      else parse_titles
      end

    parsed.map { |attrs| normalise(attrs) }.select { |attrs| attrs[:title].present? }
  end

  private

  def parse_titles
    @content.lines.map(&:strip).reject(&:blank?).uniq.map do |title|
      { type: @default_type, title: title }
    end
  end

  def parse_csv
    CSV.parse(@content, headers: true).map do |row|
      row.to_h.each_with_object({}) do |(header, value), attrs|
        key = KEY_MAP[normalise_key(header)]
        attrs[key] = value if key
      end
    end
  rescue CSV::MalformedCSVError
    []
  end

  def parse_json
    data = JSON.parse(@content)
    data = [ data ] unless data.is_a?(Array)
    data.filter_map do |object|
      next unless object.is_a?(Hash)

      object.each_with_object({}) do |(key, value), attrs|
        attr = KEY_MAP[normalise_key(key)]
        attrs[attr] = value if attr
      end
    end
  rescue JSON::ParserError
    []
  end

  def normalise_key(key)
    key.to_s.strip.downcase.gsub(/[\s-]+/, "_")
  end

  def normalise(attrs)
    result = {}
    result[:type] = resolve_type(attrs[:type])
    result[:title] = attrs[:title].to_s.strip
    result[:system] = attrs[:system].presence if attrs.key?(:system)
    result[:author] = attrs[:author].presence if attrs.key?(:author)
    result[:notes] = attrs[:notes].presence if attrs.key?(:notes)
    result[:min_players] = cast_integer(attrs[:min_players]) if attrs.key?(:min_players)
    result[:max_players] = cast_integer(attrs[:max_players]) if attrs.key?(:max_players)
    BOOLEAN_ATTRS.each { |attr| result[attr] = cast_boolean(attrs[attr]) if attrs.key?(attr) }
    result[:label_ids] = resolve_label_ids(attrs[:labels]) if attrs.key?(:labels)
    result.compact
  end

  def resolve_type(value)
    TYPE_ALIASES[value.to_s.strip.downcase] || @default_type
  end

  def cast_boolean(value)
    return value if value == true || value == false

    TRUTHY.include?(value.to_s.strip.downcase)
  end

  def cast_integer(value)
    Integer(value.to_s.strip, exception: false)
  end

  def resolve_label_ids(value)
    names = value.is_a?(Array) ? value : value.to_s.split(",")
    names = names.map { |name| name.to_s.strip }.reject(&:blank?)
    return [] if names.empty?

    labels_by_name = @user.labels.index_by { |label| label.name.downcase }
    names.filter_map do |name|
      label = labels_by_name[name.downcase]
      if label
        label.id.to_s
      else
        @unknown_labels << name
        nil
      end
    end
  end
end
