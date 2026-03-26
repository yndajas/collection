require "rails_helper"

RSpec.describe "Root", type: :request do
  describe "GET /" do
    it "returns http success and says Hello, world" do
      get "/"
      expect(response).to have_http_status(:success)
      expect(response.body).to include("Hello, world")
    end
  end
end
