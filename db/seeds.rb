User.find_or_create_by!(email: "user_with_2fa_set_up@example.com") do |user|
  user.password = "password123"
  user.otp_secret = "JBSWY3DPEHPK3PXPJBSWY3DPEHPK3PXP"
  user.consumed_timestep = 1
end

User.find_or_create_by!(email: "user_without_2fa_set_up@example.com") do |user|
  user.password = "password123"
end

User.find_or_create_by!(email: "user_exempt_from_2fa@example.com") do |user|
  user.password = "password123"
  user.otp_required_for_login = false
end
