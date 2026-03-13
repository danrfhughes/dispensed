FactoryBot.define do
  factory :organisation do
    sequence(:ods_code) { |n| "ODS#{n.to_s.rjust(3, '0')}" }
    name { "Test Organisation" }
    organisation_type { "gp_practice" }
    active { true }

    trait :gp_practice do
      organisation_type { "gp_practice" }
      name { "The Limes Medical Centre" }
    end

    trait :pharmacy do
      organisation_type { "pharmacy" }
      name { "Boots Pharmacy" }
    end
  end
end
