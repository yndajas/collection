require "rails_helper"

RSpec.describe "Authentication", type: :request do
  let(:user) { User.create!(email: "user@example.com", password: "password123") }

  describe "POST /users/sign_in" do
    it "signs the user in" do
      post user_session_path, params: { user: { email: user.email, password: user.password } }
      expect(response).to redirect_to(root_path)
      follow_redirect!
      expect(response.body).to include("Signed in successfully")
    end
  end
end
