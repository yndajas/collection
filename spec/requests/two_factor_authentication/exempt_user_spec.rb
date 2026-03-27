require "rails_helper"

RSpec.describe "Two-factor authentication exempt user", type: :request do
  let(:user) { create(:user, :exempt_from_2fa) }

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
