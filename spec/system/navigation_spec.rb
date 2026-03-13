require "rails_helper"

RSpec.describe "Navigation", type: :system do
  let(:user) { create(:user) }

  describe "when signed in" do
    before do
      sign_in user
      visit root_path
    end

    it "shows app name in header" do
      expect(page).to have_content("Dispensed")
    end

    it "navigates to dashboard" do
      click_link "Dashboard"
      expect(page).to have_current_path(dashboard_path)
    end

    it "navigates to medications" do
      click_link "Medications"
      expect(page).to have_current_path(medications_path)
    end

    it "navigates to adherence" do
      click_link "Adherence"
      expect(page).to have_current_path(adherence_path)
    end
  end

  describe "when signed out" do
    before { visit new_user_session_path }

    it "shows sign in and sign up links" do
      expect(page).to have_link("Sign in")
      expect(page).to have_link("Sign up")
    end
  end
end
