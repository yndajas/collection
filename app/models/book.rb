class Book < Collectible
  def applicable_link_keys
    %w[goodreads]
  end

  def applicable_fields
    %i[author]
  end
end
