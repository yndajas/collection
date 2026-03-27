SimpleCov.profiles.define "default" do
  add_filter "/config/"
  add_filter "/features/"
  add_filter "/spec/"
  add_filter "/vendor/"

  add_group "Controllers", "app/controllers"
  add_group "Helpers", "app/helpers"
  add_group "Libraries", "lib/"
  add_group "Models", "app/models"

  track_files "{app,lib}/**/*.rb"
end
