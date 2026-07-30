class RenamePastelCandyAndDropSugarRush < ActiveRecord::Migration[8.1]
  def up
    User.where(theme: "pastel_candy").update_all(theme: "pastel_parlour")
    # sugar_rush is being removed; move anyone on it to its sibling.
    User.where(theme: "sugar_rush").update_all(theme: "pastel_parlour")
  end

  def down
    User.where(theme: "pastel_parlour").update_all(theme: "pastel_candy")
  end
end
