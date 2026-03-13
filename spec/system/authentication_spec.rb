require "rails_helper"

RSpec.describe "Authentication", type: :system do
  let(:user) { create(:user, email: "test@example.com", password: "password123") }

  describe "sign up" do
    it "creates a new account and lands on dashboard" do
      visit new_user_registration_path

      fill_in "Email", with: "newuser@example.com"
      fill_in "Password", with: "password123"
      fill_in "Password confirmation", with: "password123"
      click_button "Sign up"

      expect(page).to have_current_path(root_path)
    end
  end

  describe "sign in" do
    it "signs in with valid credentials and lands on dashboard" do
      visit new_user_session_path

      fill_in "Email", with: user.email
      fill_in "Password", with: "password123"
      click_button "Log in"

      expect(page).to have_current_path(root_path)
    end

    it "shows error with invalid credentials" do
      visit new_user_session_path

      fill_in "Email", with: user.email
      fill_in "Password", with: "wrongpassword"
      click_button "Log in"

      expect(page).to have_content("Invalid email or password")
    end
  end

  describe "sign out" do
    it "signs out and redirects to sign-in page" do
      sign_in user
      visit root_path

      click_link "Sign out"

      expect(page).to have_current_path(new_user_session_path)
    end
  end

  describe "unauthenticated access" do
    it "redirects to sign-in when visiting dashboard" do
      visit dashboard_path

      expect(page).to have_current_path(new_user_session_path)
      expect(page).to have_content("You need to sign in or sign up before continuing")
    end
  end
end
