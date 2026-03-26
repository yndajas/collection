require "rails_helper"

RSpec.describe "Registration", type: :request do
  describe "POST /users" do
    it "registers a new user and redirects to 2FA setup" do
      post user_registration_path, params: { user: { email: "new_user@example.com", password: "password123", password_confirmation: "password123" } }
      expect(response).to redirect_to(root_path)
      follow_redirect!
      expect(response).to redirect_to(two_factor_authentication_setup_path)
    end
  end
end
