class AddCollectionUpdatedAtToUsers < ActiveRecord::Migration[8.1]
  # Dedicated "recently updated" signal for a user's collection. Unlike
  # +users.updated_at+, this is only ever bumped when a collectible is added,
  # changed, or removed, so it isn't polluted by logins, settings changes,
  # password recovery, or remember-me writes.
  def up
    add_column :users, :collection_updated_at, :datetime
    add_index :users, :collection_updated_at

    # Seed from each user's most recently touched collectible, so the recency
    # ordering is sensible from day one. Users with no collectibles stay NULL
    # and sort last.
    execute <<~SQL.squish
      UPDATE users
      SET collection_updated_at = (
        SELECT MAX(collectibles.updated_at)
        FROM collectibles
        WHERE collectibles.user_id = users.id
      )
    SQL
  end

  def down
    remove_column :users, :collection_updated_at
  end
end
