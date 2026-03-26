Then "I should see {string}" do |content|
  expect(page).to have_content(content)
end

Then "I should see a QR code" do
  expect(page).to have_selector("div.qr-code svg")
end
