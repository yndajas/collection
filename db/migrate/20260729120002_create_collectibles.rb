class CreateCollectibles < ActiveRecord::Migration[8.1]
  def change
    create_table :collectibles do |t|
      t.references :user, null: false, foreign_key: true
      t.string :type, null: false
      t.string :title, null: false
      t.text :notes
      t.boolean :completed, default: false, null: false
      t.boolean :evergreen, default: false, null: false

      # video game
      t.string :system
      t.boolean :local_multiplayer, default: false, null: false
      t.boolean :online_multiplayer, default: false, null: false
      t.boolean :cooperative, default: false, null: false
      t.boolean :competitive, default: false, null: false

      # board game
      t.integer :min_players
      t.integer :max_players

      # book
      t.string :author

      t.timestamps
    end

    add_index :collectibles, :type
    add_index :collectibles, :title
  end
end
