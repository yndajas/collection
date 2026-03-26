module TwoFactorAuthentication
  class SessionsController < ApplicationController
    skip_before_action :ensure_2fa_setup

    def show
      return redirect_to new_user_session_path if session[:otp_user_id].blank?
      @user = User.find(session[:otp_user_id])
    end

    def create
      return redirect_to new_user_session_path if session[:otp_user_id].blank?
      @user = User.find(session[:otp_user_id])

      if @user.validate_and_consume_otp!(params[:otp_attempt])
        session.delete(:otp_user_id)
        sign_in(@user)
        redirect_to root_path, notice: "Signed in successfully"
      else
        flash.now[:alert] = "Invalid OTP code"
        render :show
      end
    end
  end
end
