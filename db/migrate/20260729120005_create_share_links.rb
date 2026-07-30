class CreateShareLinks < ActiveRecord::Migration[8.1]
  def change
    create_table :share_links do |t|
      t.references :user, null: false, foreign_key: true
      t.string :token, null: false
      t.string :description
      t.datetime :expires_at
      t.timestamps
    end
    add_index :share_links, :token, unique: true
  end
end
