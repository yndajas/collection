class User < ApplicationRecord
  devise :two_factor_authenticatable,
         :database_authenticatable,
         :registerable,
         :recoverable,
         :rememberable,
         :validatable,
         otp_secret_encryption_key: Rails.application.credentials.otp_secret_encryption_key

end
