require "rails_helper"

RSpec.describe "TwoFactorAuthentication::Sessions", type: :request do
  let(:user) { User.create!(email: "user@example.com", password: "password123", otp_secret: User.generate_otp_secret, consumed_timestep: 1) }

  describe "GET /two_factor_authentication/session" do
    context "when otp_user_id is in session" do
      before do
        post user_session_path, params: { user: { email: user.email, password: user.password } }
      end

      it "returns http success" do
        get two_factor_authentication_session_path
        expect(response).to have_http_status(:success)
        expect(response.body).to include("Verify two-factor authentication")
      end
    end

    context "when otp_user_id is missing" do
      it "redirects to sign in" do
        get two_factor_authentication_session_path
        expect(response).to redirect_to(new_user_session_path)
      end
    end
  end

  describe "POST /two_factor_authentication/session" do
    before do
      post user_session_path, params: { user: { email: user.email, password: user.password } }
    end

    context "with valid OTP" do
      it "signs in the user and redirects to root" do
        post two_factor_authentication_session_path, params: { otp_attempt: user.current_otp }
        expect(response).to redirect_to(root_path)
        expect(flash[:notice]).to eq("Signed in successfully")
      end
    end

    context "with invalid OTP" do
      it "renders show with alert" do
        post two_factor_authentication_session_path, params: { otp_attempt: "000000" }
        expect(response).to have_http_status(:success)
        expect(response.body).to include("Invalid OTP code")
      end
    end
  end
end
