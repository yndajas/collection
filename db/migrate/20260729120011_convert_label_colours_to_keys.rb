class ConvertLabelColoursToKeys < ActiveRecord::Migration[8.1]
  # Map the old seed/default hex colours to the new named palette keys.
  HEX_TO_KEY = {
    "#e0733d" => "orange",
    "#8a3ffc" => "purple",
    "#1d9a6c" => "green"
  }.freeze

  def up
    change_column_default :labels, :colour, "blue"
    Label.reset_column_information
    Label.find_each do |label|
      key = HEX_TO_KEY[label.colour] || "blue"
      label.update_columns(colour: key)
    end
  end

  def down
    change_column_default :labels, :colour, "#4f6bed"
  end
end
