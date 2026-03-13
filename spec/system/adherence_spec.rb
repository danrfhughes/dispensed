require "rails_helper"

RSpec.describe "Adherence", type: :system do
  let(:user) { create(:user) }

  before { sign_in user }

  describe "empty state" do
    it "shows message when no active medications" do
      visit adherence_path

      expect(page).to have_content("Adherence")
      expect(page).to have_content("No active medications")
    end
  end

  describe "with medications and doses" do
    let!(:medication) { create(:medication, user: user, name: "Metformin", dose: "500mg") }
    let!(:schedule) { create(:schedule, medication: medication, time_of_day: "08:00", days_of_week: "daily") }

    before do
      # Create doses over the past 7 days
      7.times do |i|
        dose = create(:dose,
          medication: medication,
          schedule: schedule,
          scheduled_for: (i + 1).days.ago.change(hour: 8),
          status: i < 5 ? "taken" : "missed"
        )
        dose.update!(taken_at: dose.scheduled_for + 10.minutes) if dose.status == "taken"
      end
    end

    it "shows per-medication breakdown" do
      visit adherence_path

      expect(page).to have_content("Metformin")
      expect(page).to have_content("500mg")
    end

    it "shows 7-day and 28-day columns" do
      visit adherence_path

      expect(page).to have_content("Last 7 days")
      expect(page).to have_content("Last 28 days")
    end

    it "shows dose count" do
      visit adherence_path

      expect(page).to have_content(/\d+\/\d+ doses/)
    end
  end
end
