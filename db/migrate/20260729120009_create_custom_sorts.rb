class CreateCustomSorts < ActiveRecord::Migration[8.1]
  def change
    # Replaced by the custom_sorts table below (users can have several).
    remove_column :users, :custom_sort, :json, default: [], null: false

    create_table :custom_sorts do |t|
      t.references :user, null: false, foreign_key: true
      t.string :name, null: false
      # Ordered list of { "field" => ..., "direction" => "asc"|"desc" }.
      t.json :criteria, default: [], null: false
      t.timestamps
    end
    add_index :custom_sorts, [ :user_id, :name ], unique: true
  end
end
