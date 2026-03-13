require "rails_helper"

RSpec.describe User, type: :model do
  describe "#admin?" do
    it "returns true when role is admin" do
      user = build(:user, role: "admin")
      expect(user.admin?).to be true
    end

    it "returns false when role is patient" do
      user = build(:user, role: "patient")
      expect(user.admin?).to be false
    end
  end

  describe "#patient?" do
    it "returns true when role is patient" do
      user = build(:user, role: "patient")
      expect(user.patient?).to be true
    end

    it "returns false when role is admin" do
      user = build(:user, role: "admin")
      expect(user.patient?).to be false
    end
  end

  describe ".from_omniauth" do
    let(:auth) do
      OmniAuth::AuthHash.new(
        provider: "nhslogin",
        uid: "nhs-sub-12345",
        info: {
          email: "patient@nhs.net",
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

    it "creates a new user from an auth hash" do
      expect { User.from_omniauth(auth) }.to change(User, :count).by(1)
    end

    it "sets provider and uid on the user" do
      user = User.from_omniauth(auth)
      expect(user.provider).to eq("nhslogin")
      expect(user.uid).to eq("nhs-sub-12345")
    end

    it "sets email from the auth hash" do
      user = User.from_omniauth(auth)
      expect(user.email).to eq("patient@nhs.net")
    end

    it "creates a patient profile automatically" do
      user = User.from_omniauth(auth)
      expect(user.patient_profile).to be_present
    end

    it "returns the existing user on subsequent calls" do
      first = User.from_omniauth(auth)
      second = User.from_omniauth(auth)
      expect(first.id).to eq(second.id)
    end

    it "does not overwrite email on existing user" do
      user = User.from_omniauth(auth)
      auth.info.email = "different@nhs.net"
      same_user = User.from_omniauth(auth)
      expect(same_user.email).to eq("patient@nhs.net")
    end
  end

  describe "#password_required?" do
    it "returns false for NHS Login users" do
      user = build(:user, provider: "nhslogin", uid: "nhs-123", password: nil)
      expect(user.password_required?).to be false
    end

    it "returns true for email/password users" do
      user = build(:user, provider: nil, uid: nil)
      expect(user.password_required?).to be true
    end
  end
end
