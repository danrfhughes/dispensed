require "rails_helper"

RSpec.describe "NHS Login", type: :system do
  before do
    OmniAuth.config.test_mode = true
  end

  after do
    OmniAuth.config.test_mode = false
    OmniAuth.config.mock_auth[:nhslogin] = nil
  end

  describe "sign in page" do
    it "shows NHS Login button" do
      visit new_user_session_path

      expect(page).to have_button("Continue with NHS Login")
    end
  end

  describe "successful login" do
    before do
      OmniAuth.config.mock_auth[:nhslogin] = OmniAuth::AuthHash.new(
        provider: "nhslogin",
        uid: "nhs-uid-123",
        info: {
          email: "jane@nhs.net",
          name: "Jane Smith"
        },
        extra: {
          raw_info: {
            nhs_number: "9876543210",
            identity_proofing_level: "P5"
          }
        }
      )
    end

    it "creates a new user and lands on dashboard" do
      visit new_user_session_path
      click_button "Continue with NHS Login"

      expect(page).to have_current_path(root_path)
      expect(User.last.provider).to eq("nhslogin")
    end

    it "signs in a returning user" do
      # First login
      visit new_user_session_path
      click_button "Continue with NHS Login"

      # Sign out
      click_link "Sign out"

      # Second login
      visit new_user_session_path
      click_button "Continue with NHS Login"

      expect(page).to have_current_path(root_path)
      expect(User.where(provider: "nhslogin").count).to eq(1)
    end
  end

  describe "failed login" do
    before do
      OmniAuth.config.mock_auth[:nhslogin] = :invalid_credentials
    end

    it "shows error and returns to sign-in page" do
      visit new_user_session_path
      click_button "Continue with NHS Login"

      expect(page).to have_current_path(new_user_session_path)
    end
  end
end
