Given "a user exists with email {string} and password {string}" do |email, password|
  User.create!(email: email, password: password)
end

When "I follow {string}" do |link|
  click_link link
end

When "I fill in {string} with {string}" do |field, value|
  fill_in field, with: value
end

When "I press {string}" do |button|
  click_button button
end


Given "the user has not set up 2FA" do
  # This is the default state
  user = User.last
  expect(user.consumed_timestep).to be_nil
end
