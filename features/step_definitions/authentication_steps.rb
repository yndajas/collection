Given "a user exists with email {string} and password {string}" do |email, password|
  User.create!(email:, password:)
end

Given "the user has not set up 2FA" do
  # This is the default state
  user = User.last
  expect(user.consumed_timestep).to be_nil
end

Given "the user has set up 2FA" do
  user = User.last
  user.update!(otp_secret: User.generate_otp_secret, consumed_timestep: 1)
end

When "I fill in \"OTP\" with a valid code for {string}" do |email|
  user = User.find_by!(email:)
  fill_in "OTP", with: user.current_otp
end

Given "the user is exempt from 2FA" do
  user = User.last
  user.update!(otp_required_for_login: false)
end
