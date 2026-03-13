require "rails_helper"

RSpec.describe "Medications", type: :system do
  let(:user) { create(:user) }

  before { sign_in user }

  describe "index" do
    it "lists active medications" do
      create(:medication, user: user, name: "Metformin", dose: "500mg")
      create(:medication, user: user, name: "Atorvastatin", dose: "20mg")
      visit medications_path

      expect(page).to have_content("Metformin")
      expect(page).to have_content("Atorvastatin")
    end

    it "shows empty state when no medications" do
      visit medications_path

      expect(page).to have_link("Add medication")
    end

    it "does not show other users medications" do
      other_user = create(:user)
      create(:medication, user: other_user, name: "SecretMed")
      visit medications_path

      expect(page).not_to have_content("SecretMed")
    end
  end

  describe "create" do
    it "adds a new medication via form" do
      visit new_medication_path

      fill_in "Name", with: "Lisinopril"
      fill_in "Dose", with: "10mg"
      fill_in "Form (tablet, capsule, etc.)", with: "tablet"
      click_button "Create Medication"

      expect(page).to have_content("Medication added")
      expect(page).to have_content("Lisinopril")
    end

    it "shows validation errors for blank name" do
      visit new_medication_path

      fill_in "Name", with: ""
      click_button "Create Medication"

      expect(page).to have_content("can't be blank")
    end
  end

  describe "edit" do
    let!(:medication) { create(:medication, user: user, name: "Metformin", dose: "500mg") }

    it "updates medication details" do
      visit edit_medication_path(medication)

      fill_in "Dose", with: "1000mg"
      click_button "Update Medication"

      expect(page).to have_content("Medication updated")
    end
  end

  describe "archive" do
    let!(:medication) { create(:medication, user: user, name: "OldMed", dose: "5mg") }

    it "archives a medication" do
      visit medications_path

      click_button "Archive"

      expect(page).to have_content("Medication archived")
    end
  end

  describe "show" do
    let!(:medication) { create(:medication, user: user, name: "Metformin", dose: "500mg") }

    it "displays medication details and schedules section" do
      visit medication_path(medication)

      expect(page).to have_content("Metformin")
      expect(page).to have_content("500mg")
      expect(page).to have_content("Schedules")
      expect(page).to have_link("Add schedule")
    end
  end
end
