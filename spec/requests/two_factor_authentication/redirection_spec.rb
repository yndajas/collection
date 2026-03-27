require "rails_helper"

RSpec.describe "Two-factor authentication redirection", type: :request do
  let(:user) { create(:user) }

  context "when user is not signed in" do
    it "does not redirect to 2FA setup" do
      get root_path
      expect(response).not_to redirect_to(two_factor_authentication_setup_path)
    end
  end

  context "when user is signed in" do
    before { sign_in user }

    context "and has not completed 2FA setup (consumed_timestep is nil)" do
      it "redirects to 2FA setup from the home page" do
        get root_path
        expect(response).to redirect_to(two_factor_authentication_setup_path)
      end

      it "does not redirect when already on the 2FA setup page" do
        get two_factor_authentication_setup_path
        expect(response).to have_http_status(:success)
      end

      it "does not redirect when on a Devise controller (e.g., sign out)" do
        delete destroy_user_session_path
        expect(response).to redirect_to(root_path)
      end
    end

    context "and has completed 2FA setup (consumed_timestep is present)" do
      before { user.update!(consumed_timestep: 123456) }

      it "does not redirect to 2FA setup" do
        get root_path
        expect(response).to have_http_status(:success)
      end
    end
  end
end
