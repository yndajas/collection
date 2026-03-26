require "rails_helper"

RSpec.describe "TwoFactorAuthentication::ExemptUser", type: :request do
  let(:user) { User.create!(email: "exempt@example.com", password: "password123", otp_required_for_login: false) }

  describe "POST /users/sign_in" do
    it "logs in the user and redirects to root without 2FA setup" do
      post user_session_path, params: { user: { email: user.email, password: user.password } }
      expect(response).to redirect_to(root_path)
      follow_redirect!
      expect(response.body).to include("Signed in successfully")
      expect(response.body).to include("Hello, world")
    end
  end

  describe "GET /" do
    it "does not redirect to 2FA setup after login" do
      sign_in user
      get root_path
      expect(response).to have_http_status(:success)
      expect(response.body).to include("Hello, world")
    end
  end
end
