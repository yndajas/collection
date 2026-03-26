require "rails_helper"

RSpec.describe "Authentication", type: :request do
  let(:user) { User.create!(email: "user@example.com", password: "password123") }

  describe "POST /users/sign_in" do
    context "when 2FA is not yet set up" do
      it "redirects to 2FA setup" do
        post user_session_path, params: { user: { email: user.email, password: user.password } }
        expect(response).to redirect_to(root_path)
        follow_redirect!
        expect(response).to redirect_to(two_factor_authentication_setup_path)
      end
    end

    context "when 2FA is already set up" do
      before { user.update!(otp_secret: User.generate_otp_secret, consumed_timestep: 1) }

      it "redirects to 2FA challenge" do
        post user_session_path, params: { user: { email: user.email, password: user.password } }
        expect(response).to redirect_to(two_factor_authentication_session_path)
      end
    end
  end
end
