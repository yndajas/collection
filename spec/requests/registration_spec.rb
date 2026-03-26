require 'rails_helper'

RSpec.describe 'Registration', type: :request do
  describe 'POST /users' do
    it 'registers a new user' do
      post user_registration_path, params: { user: { email: 'new_user@example.com', password: 'password123', password_confirmation: 'password123' } }
      expect(response).to redirect_to(root_path)
      follow_redirect!
      expect(response.body).to include('Welcome! You have signed up successfully')
    end
  end
end
