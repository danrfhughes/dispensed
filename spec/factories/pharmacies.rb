FactoryBot.define do
  factory :pharmacy do
    name { "MyString" }
    address { "MyText" }
    phone { "MyString" }
    email { "MyString" }
    patient_profile { nil }
  end
end
