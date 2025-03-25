module Enedis
  class MockOauthService
    attr_reader :user

    def initialize(user)
      @user = user
    end

    # Simule l'URL d'autorisation avec notre mock
    def authorization_url(options = {})
      state = options[:state] || SecureRandom.hex(16)
      Rails.application.routes.url_helpers.oauth_callback_mock_path(state: state)
    end

    def exchange_authorization_code(code, redirect_uri)
      # Utilise le service d'authentification réel pour obtenir un token
      auth_service = Enedis::AuthService.new(user)
      token = auth_service.authenticate

      user.update(
        enedis_token: token,
        enedis_token_expires_at: 1.hour.from_now,
        enedis_refresh_token: nil
      )

      {
        "access_token" => token,
        "token_type" => "Bearer",
        "expires_in" => 3600
      }
    end
  end
end
