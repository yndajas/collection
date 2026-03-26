module TwoFactorAuthentication
  class SetupController < ApplicationController
    before_action :authenticate_user!

    def show
      prepare_2fa
    end

    def update
      if current_user.validate_and_consume_otp!(params[:otp_attempt])
        current_user.save!
        redirect_to root_path, notice: "Two-factor authentication enabled"
      else
        prepare_2fa
        flash.now[:alert] = "Invalid OTP code"
        render :show
      end
    end

    private

    def prepare_2fa
      ensure_otp_secret
      issuer = "Collection"
      label = "#{issuer}:#{current_user.email}"
      @provisioning_uri = current_user.otp_provisioning_uri(label, issuer: issuer)
      @qrcode = RQRCode::QRCode.new(@provisioning_uri).as_svg(module_size: 4).html_safe
    end

    def ensure_otp_secret
      return if current_user.otp_secret.present?
      current_user.update!(otp_secret: User.generate_otp_secret)
    end
  end
end
