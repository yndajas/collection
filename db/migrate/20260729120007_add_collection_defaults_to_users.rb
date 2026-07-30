class AddCollectionDefaultsToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :collection_sort, :string, default: "updated", null: false
    add_column :users, :collection_view, :string, default: "cards", null: false
  end
end
