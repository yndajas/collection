class AddCollectibleTypesToLabels < ActiveRecord::Migration[8.1]
  def change
    add_column :labels, :collectible_types, :json, default: [], null: false
  end
end
