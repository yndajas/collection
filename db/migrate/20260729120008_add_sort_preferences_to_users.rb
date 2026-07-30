class AddSortPreferencesToUsers < ActiveRecord::Migration[8.1]
  def change
    # Ordered list of { "field" => ..., "direction" => "asc"|"desc" } making up
    # the user's custom compound sort.
    add_column :users, :custom_sort, :json, default: [], null: false
    # Default sort keys the user has chosen to hide from the sort dropdown.
    add_column :users, :hidden_default_sorts, :json, default: [], null: false
  end
end
