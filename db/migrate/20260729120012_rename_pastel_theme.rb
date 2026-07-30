class RenamePastelTheme < ActiveRecord::Migration[8.1]
  def up
    User.where(theme: "pastel").update_all(theme: "pastel_woodland")
  end

  def down
    User.where(theme: "pastel_woodland").update_all(theme: "pastel")
  end
end
