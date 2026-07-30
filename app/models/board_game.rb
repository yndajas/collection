class BoardGame < Collectible
  def applicable_link_keys
    %w[boardgamegeek youtube]
  end

  def applicable_fields
    %i[min_players max_players cooperative competitive]
  end

  def player_count
    return if min_players.blank? && max_players.blank?
    return "#{min_players}+" if max_players.blank?
    return "up to #{max_players}" if min_players.blank?
    return min_players.to_s if min_players == max_players

    "#{min_players}-#{max_players}"
  end
end
