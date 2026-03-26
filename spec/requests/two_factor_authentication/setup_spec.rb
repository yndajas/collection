require "rails_helper"

RSpec.describe "Two-factor authentication setup", type: :request do
  let(:user) { User.create!(email: "user@example.com", password: "password123") }

  before { sign_in user }

  describe "GET /two_factor_authentication/setup" do
    it "returns http success and shows QR code" do
      get two_factor_authentication_setup_path
      expect(response).to have_http_status(:success)
      expect(response.body).to include("Set up two-factor authentication")
      expect(response.body).to include("svg")
    end
  end

  describe "PATCH /two_factor_authentication/setup" do
    context "with valid OTP" do
      before { user.update!(otp_secret: User.generate_otp_secret) }

      it "enables 2FA and redirects to root" do
        patch two_factor_authentication_setup_path, params: { otp_attempt: user.current_otp }
        expect(response).to redirect_to(root_path)
        user.reload
        expect(user.consumed_timestep).not_to be_nil
      end
    end

    context "with invalid OTP" do
      it "renders show with alert" do
        patch two_factor_authentication_setup_path, params: { otp_attempt: "000000" }
        expect(response).to have_http_status(:success)
        expect(response.body).to include("Invalid OTP code")
      end
    end
  end
end
