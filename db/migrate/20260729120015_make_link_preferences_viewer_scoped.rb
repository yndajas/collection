class MakeLinkPreferencesViewerScoped < ActiveRecord::Migration[8.1]
  # Snapshot of Collectible::LINK_KEYS at migration time, so the data backfill
  # doesn't couple to the live constant.
  LINK_KEYS = %w[
    psnprofiles psnprofiles_guides psprices metacritic opencritic youtube steam
    howlongtobeat boardgamegeek goodreads
  ].freeze

  def up
    add_column :users, :hidden_link_keys, :json, default: [], null: false
    add_column :users, :hide_links_on_others, :boolean, default: false, null: false

    # visible_link_keys was an inclusion list; the viewer-scoped model stores the
    # complement, so invert each user's list into the keys they've hidden.
    User.reset_column_information
    User.find_each do |user|
      visible = Array(user.read_attribute(:visible_link_keys))
      user.update_columns(hidden_link_keys: LINK_KEYS - visible)
    end

    remove_column :users, :visible_link_keys
  end

  def down
    add_column :users, :visible_link_keys, :json, default: [], null: false
    User.reset_column_information
    User.find_each do |user|
      user.update_columns(visible_link_keys: LINK_KEYS - Array(user.read_attribute(:hidden_link_keys)))
    end
    remove_column :users, :hide_links_on_others
    remove_column :users, :hidden_link_keys
  end
end
