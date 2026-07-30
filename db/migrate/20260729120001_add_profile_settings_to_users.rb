class AddProfileSettingsToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :username, :string
    add_column :users, :display_name, :string
    add_column :users, :public_profile, :boolean, default: false, null: false
    add_column :users, :visible_link_keys, :json, default: [], null: false
    add_index :users, :username, unique: true
    add_index :users, :public_profile
  end
end
