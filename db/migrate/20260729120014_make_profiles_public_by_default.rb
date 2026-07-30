class MakeProfilesPublicByDefault < ActiveRecord::Migration[8.1]
  def change
    change_column_default :users, :public_profile, from: false, to: true
  end
end
