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

    context "when user has no otp_secret" do
      it "generates an otp_secret" do
        expect { get two_factor_authentication_setup_path }.to change { user.reload.otp_secret }.from(nil)
      end
    end

    context "when user already has an otp_secret" do
      before { user.update!(otp_secret: User.generate_otp_secret) }

      it "does not generate a new secret" do
        expect { get two_factor_authentication_setup_path }.not_to change { user.reload.otp_secret }
      end
    end
  end

  describe "PATCH /two_factor_authentication/setup" do
    context "when the user already has an otp_secret" do
      before { user.update!(otp_secret: User.generate_otp_secret) }

      context "and they provide a valid otp_attempt" do
        it "enables 2FA and redirects to root" do
          patch two_factor_authentication_setup_path, params: { otp_attempt: user.current_otp }
          expect(response).to redirect_to(root_path)
          expect(user.reload.consumed_timestep).not_to be_nil
        end
      end

      context "and they provide an invalid otp_attempt" do
        it "renders show with alert" do
          patch two_factor_authentication_setup_path, params: { otp_attempt: "000000" }
          expect(response).to have_http_status(:success)
          expect(response.body).to include("Invalid OTP code")
        end

        it "does not generate a new secret" do
          expect { patch two_factor_authentication_setup_path, params: { otp_attempt: "000000" } }.not_to change { user.reload.otp_secret }
        end
      end
    end

    context "when the user has no otp_secret" do
      it "generates an otp_secret" do
        expect { patch two_factor_authentication_setup_path, params: { otp_attempt: "000000" } }.to change { user.reload.otp_secret }.from(nil)
      end

      it "renders show with alert" do
        patch two_factor_authentication_setup_path, params: { otp_attempt: "000000" }
        expect(response).to have_http_status(:success)
        expect(response.body).to include("Invalid OTP code")
      end
    end
  end
end
