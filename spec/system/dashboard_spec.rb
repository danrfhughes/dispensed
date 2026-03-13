require "rails_helper"

RSpec.describe "Dashboard", type: :system do
  let(:user) { create(:user) }
  let(:patient_profile) { user.patient_profile }

  before { sign_in user }

  describe "basic display" do
    it "shows a greeting with the time of day" do
      visit dashboard_path

      expect(page).to have_content(/Good (morning|afternoon|evening)/)
    end

    it "shows the user email when no patient name" do
      visit dashboard_path

      expect(page).to have_content(user.email)
    end

    it "shows the patient name when demographics present" do
      patient_profile.update!(first_name: "Jane", last_name: "Smith")
      visit dashboard_path

      expect(page).to have_content("Jane Smith")
    end

    it "shows formatted NHS number when present" do
      patient_profile.update!(nhs_number: "1234567890")
      visit dashboard_path

      expect(page).to have_content("123 456 7890")
    end
  end

  describe "empty state" do
    it "shows dashboard without errors when no medications" do
      visit dashboard_path

      expect(page).to have_content(/Good (morning|afternoon|evening)/)
      expect(page).to have_link("My medications")
    end
  end

  describe "with medications and doses" do
    let!(:medication) do
      create(:medication, user: user, name: "Metformin", dose: "500mg")
    end
    let!(:schedule) do
      create(:schedule, medication: medication, time_of_day: "08:00", days_of_week: "daily")
    end

    it "shows medication name on dashboard" do
      visit dashboard_path

      expect(page).to have_content("Metformin")
    end

    it "shows dose information" do
      visit dashboard_path

      expect(page).to have_content("500mg")
    end
  end

  describe "reorder alerts" do
    it "shows reorder banner when medication needs reorder" do
      create(:medication,
        user: user,
        name: "Atorvastatin",
        dose: "20mg",
        days_supply: 28,
        last_dispensed_on: 35.days.ago.to_date
      )
      visit dashboard_path

      expect(page).to have_content("Reorder overdue")
    end
  end

  describe "GP and pharmacy cards" do
    it "shows GP practice when present" do
      gp = create(:organisation, :gp_practice, name: "Riverside Surgery")
      patient_profile.update!(gp_organisation_id: gp.id)
      visit dashboard_path

      expect(page).to have_content("Riverside Surgery")
    end

    it "shows nominated pharmacy when present" do
      pharmacy = create(:organisation, :pharmacy, name: "Boots Pharmacy")
      patient_profile.update!(nominated_pharmacy_id: pharmacy.id)
      visit dashboard_path

      expect(page).to have_content("Boots Pharmacy")
    end
  end
end
