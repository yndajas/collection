Given "I am on the home page" do
  visit root_path
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

Then "I should see {string}" do |content|
  expect(page).to have_content(content)
end

Then "I should see a QR code" do
  expect(page).to have_selector("div.qr-code svg")
end
