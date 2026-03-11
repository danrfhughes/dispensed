require "rails_helper"

RSpec.describe "Adherence", type: :request do
  let(:user) { create(:user) }
  before { sign_in user }

  describe "GET /adherence" do
    it "returns http success" do
      get adherence_path
      expect(response).to have_http_status(:ok)
    end
  end
end
