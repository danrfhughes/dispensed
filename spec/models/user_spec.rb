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
end
