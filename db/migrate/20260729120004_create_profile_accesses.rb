class CreateProfileAccesses < ActiveRecord::Migration[8.1]
  def change
    create_table :profile_accesses do |t|
      t.references :owner, null: false, foreign_key: { to_table: :users }
      t.references :viewer, null: false, foreign_key: { to_table: :users }
      t.timestamps
    end
    add_index :profile_accesses, [ :owner_id, :viewer_id ], unique: true
  end
end
