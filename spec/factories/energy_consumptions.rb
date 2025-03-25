FactoryBot.define do
  factory :energy_consumption, class: 'Enedis::EnergyConsumption' do
    association :user
    usage_point_id { "12345678901234" }
    date { "2025-03-13" }
    value { 1.5 }
    unit { "kWh" }
    measuring_period { "DAILY" }
    measurement_kind { "consumption" }
  end
end
