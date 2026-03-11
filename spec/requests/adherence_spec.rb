require "rails_helper"

RSpec.describe "Adherence", type: :request do
  let(:user) { create(:user) }
  before { sign_in user }

  describe "GET /adherence" do
    it "returns http success with no medications" do
      get adherence_path
      expect(response).to have_http_status(:ok)
    end

    it "computes adherence stats for active medications with doses" do
      medication = create(:medication, patient_profile: user.patient_profile)
      schedule   = create(:schedule, medication: medication)
      create(:dose, medication: medication, schedule: schedule,
             scheduled_for: 1.hour.ago, status: "taken", taken_at: 50.minutes.ago)
      create(:dose, medication: medication, schedule: schedule,
             scheduled_for: 2.hours.ago, status: "pending")

      get adherence_path
      expect(response).to have_http_status(:ok)
    end
  end
end
