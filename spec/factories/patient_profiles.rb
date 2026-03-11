FactoryBot.define do
  factory :patient_profile do
    association :user
    nhs_number { nil }
    date_of_birth { 30.years.ago.to_date }
  end
end