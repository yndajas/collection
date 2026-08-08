class RenameCollectionSortToCollectiblesSortOnUsers < ActiveRecord::Migration[8.1]
  # collection_sort orders the collectibles within a collection. Rename it to
  # collectibles_sort so it reads clearly alongside the new collections_sort
  # (which orders the list of collections).
  def change
    rename_column :users, :collection_sort, :collectibles_sort
  end
end
