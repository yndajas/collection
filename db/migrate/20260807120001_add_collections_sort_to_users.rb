class AddCollectionsSortToUsers < ActiveRecord::Migration[8.1]
  # The viewer's remembered sort for the all-collections list (recent | name).
  def change
    add_column :users, :collections_sort, :string, default: "recent", null: false
  end
end
