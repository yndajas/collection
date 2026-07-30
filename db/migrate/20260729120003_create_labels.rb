class CreateLabels < ActiveRecord::Migration[8.1]
  def change
    create_table :labels do |t|
      t.references :user, null: false, foreign_key: true
      t.string :name, null: false
      t.string :colour, default: "#4f6bed", null: false
      t.timestamps
    end
    add_index :labels, [ :user_id, :name ], unique: true

    create_table :collectible_labels do |t|
      t.references :collectible, null: false, foreign_key: true
      t.references :label, null: false, foreign_key: true
      t.timestamps
    end
    add_index :collectible_labels, [ :collectible_id, :label_id ], unique: true
  end
end
