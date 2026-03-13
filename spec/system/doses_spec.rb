require "rails_helper"

RSpec.describe "Doses", type: :system do
  let(:user) { create(:user) }
  let!(:medication) { create(:medication, user: user, name: "Metformin", dose: "500mg") }
  let!(:schedule) { create(:schedule, medication: medication, time_of_day: "08:00", days_of_week: "daily") }

  before { sign_in user }

  describe "marking doses" do
    let!(:dose) do
      create(:dose,
        medication: medication,
        schedule: schedule,
        scheduled_for: Time.current.change(hour: 8),
        status: "pending"
      )
    end

    it "marks a dose as taken" do
      page.driver.submit :patch, take_dose_path(dose), {}

      expect(dose.reload.status).to eq("taken")
      expect(dose.taken_at).to be_present
    end

    it "marks a dose as skipped" do
      page.driver.submit :patch, skip_dose_path(dose), {}

      expect(dose.reload.status).to eq("skipped")
    end
  end

  describe "ownership isolation" do
    let(:other_user) { create(:user) }
    let(:other_medication) { create(:medication, user: other_user, name: "OtherMed") }
    let(:other_schedule) { create(:schedule, medication: other_medication, time_of_day: "08:00") }
    let!(:other_dose) do
      create(:dose,
        medication: other_medication,
        schedule: other_schedule,
        scheduled_for: Time.current,
        status: "pending"
      )
    end

    it "cannot take another users dose" do
      expect {
        page.driver.submit :patch, take_dose_path(other_dose), {}
      }.not_to change { other_dose.reload.status }
    end
  end
end
