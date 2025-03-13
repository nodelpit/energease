FactoryBot.define do
  factory :energy_consumption do
    user { nil }
    usage_point_id { "MyString" }
    date { "2025-03-13" }
    value { 1.5 }
    unit { "MyString" }
    measuring_period { "MyString" }
    measurement_kind { "MyString" }
  end
end
