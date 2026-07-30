class VideoGame < Collectible
  def applicable_link_keys
    %w[psnprofiles psnprofiles_guides psprices metacritic opencritic youtube steam howlongtobeat]
  end

  def applicable_fields
    %i[system local_multiplayer online_multiplayer cooperative competitive]
  end

  def multiplayer?
    local_multiplayer? || online_multiplayer?
  end
end
