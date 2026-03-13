require "rails_helper"

RSpec.describe "NHS Login OmniAuth Callbacks", type: :request do
  before do
    OmniAuth.config.test_mode = true
  end

  after do
    OmniAuth.config.mock_auth[:nhslogin] = nil
  end

  let(:mock_auth) do
    OmniAuth::AuthHash.new(
      provider: "nhslogin",
      uid: "nhs-sub-99999",
      info: {
        email: "jane.smith@nhs.net",
        name: "Jane Smith",
        birthdate: "1955-03-15"
      },
      extra: {
        raw_info: { vot: "P5.Cp.Cd", nhs_number: "9876543210" },
        vot: "P5",
        nhs_number: "9876543210"
      }
    )
  end

  # OmniAuth test mode: POST to authorize → 302 to callback → controller action
  def sign_in_via_nhslogin
    post user_nhslogin_omniauth_authorize_path
    follow_redirect!
  end

  describe "POST /users/auth/nhslogin/callback" do
    before do
      OmniAuth.config.mock_auth[:nhslogin] = mock_auth
    end

    it "creates a new user and signs them in" do
      expect { sign_in_via_nhslogin }.to change(User, :count).by(1)
      expect(response).to redirect_to(root_path)
    end

    it "sets provider and uid on the user" do
      sign_in_via_nhslogin
      user = User.last
      expect(user.provider).to eq("nhslogin")
      expect(user.uid).to eq("nhs-sub-99999")
    end

    it "updates patient profile with NHS identity level" do
      sign_in_via_nhslogin
      profile = User.last.patient_profile
      expect(profile.nhs_login_identity_level).to eq("P5")
    end

    it "populates NHS number on patient profile" do
      sign_in_via_nhslogin
      profile = User.last.patient_profile
      expect(profile.nhs_number).to eq("9876543210")
    end

    it "signs in existing user on repeat login" do
      sign_in_via_nhslogin
      expect(User.count).to eq(1)

      delete destroy_user_session_path
      sign_in_via_nhslogin
      expect(User.count).to eq(1)
    end

    context "with P0 identity level (no NHS number)" do
      let(:mock_auth) do
        OmniAuth::AuthHash.new(
          provider: "nhslogin",
          uid: "nhs-sub-p0-user",
          info: { email: "unverified@example.com" },
          extra: {
            raw_info: { vot: "P0.Cp" },
            vot: "P0",
            nhs_number: nil
          }
        )
      end

      it "creates user without NHS number" do
        sign_in_via_nhslogin
        profile = User.last.patient_profile
        expect(profile.nhs_login_identity_level).to eq("P0")
        expect(profile.nhs_number).to be_nil
      end
    end
  end

  describe "authentication failure" do
    before do
      OmniAuth.config.mock_auth[:nhslogin] = :invalid_credentials
    end

    it "redirects with an error on failure" do
      post user_nhslogin_omniauth_authorize_path
      follow_redirect! # authorize → failure callback
      expect(response).to redirect_to(root_path)
    end
  end
end
