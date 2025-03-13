FactoryBot.define do
  factory :user do
    sequence(:email) { |n| "user#{n}@example.com" }
    password { "password123" }

    # Champs Enedis
    usage_point_id { nil }
    enedis_token { nil }
    enedis_token_expires_at { nil }
    enedis_refresh_token { nil }

    # User avec token valide
    trait :with_valid_token do
      enedis_token { "valid_token" }
      enedis_token_expires_at { 1.hour.from_now }
    end

    # User avec token expiré
    trait :with_expired_token do
      enedis_token { "expired_token" }
      enedis_token_expires_at { 1.hour.ago }
    end
  end
end
