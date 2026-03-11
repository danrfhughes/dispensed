require "rails_helper"

RSpec.describe "Doses", type: :request do
  let(:user)       { create(:user) }
  let(:medication) { create(:medication, patient_profile: user.patient_profile) }
  let(:schedule)   { create(:schedule, medication: medication) }
  let(:dose)       { create(:dose, medication: medication, schedule: schedule) }

  before { sign_in user }

  describe "PATCH /doses/:id/take" do
    it "marks the dose as taken and redirects" do
      patch take_dose_path(dose)
      expect(dose.reload.status).to eq("taken")
      expect(response).to redirect_to(dashboard_path)
    end

    it "requires authentication" do
      sign_out user
      patch take_dose_path(dose)
      expect(response).to redirect_to(new_user_session_path)
    end
  end

  describe "PATCH /doses/:id/skip" do
    it "marks the dose as skipped and redirects" do
      patch skip_dose_path(dose)
      expect(dose.reload.status).to eq("skipped")
      expect(response).to redirect_to(dashboard_path)
    end

    it "requires authentication" do
      sign_out user
      patch skip_dose_path(dose)
      expect(response).to redirect_to(new_user_session_path)
    end
  end

  describe "ownership isolation" do
    it "returns 404 when another user tries to update someone else's dose" do
      other_user = create(:user)
      sign_in other_user
      patch take_dose_path(dose)
      expect(response).to have_http_status(:not_found)
    end
  end
end
