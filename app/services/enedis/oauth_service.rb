module Enedis
  class OauthService
    attr_reader :user

    def initialize(user)
      @user = user
    end

    # Génère l'URL d'autorisation Enedis officielle
    def authorization_url(options = {})
      callback_url = options[:callback_url]
      state = options[:state] || SecureRandom.hex(16)

      client_id = ENV.fetch("ENEDIS_PUBLIC_KEY")
      base_url = ENV.fetch("ENEDIS_API_BASE_URL", "https://gw.ext.prod-sandbox.api.enedis.fr")

      "#{base_url}/dataconnect/v1/oauth2/authorize?client_id=#{client_id}&state=#{state}&response_type=code&redirect_uri=#{CGI.escape(callback_url)}"
    end


    # Échange un code d'autorisation contre un token d'accès
    def exchange_authorization_code(code, redirect_uri)
      client_id = ENV.fetch("ENEDIS_PUBLIC_KEY")
      client_secret = ENV.fetch("ENEDIS_PRIVATE_KEY")
      base_url = ENV.fetch("ENEDIS_API_BASE_URL", "https://gw.ext.prod-sandbox.api.enedis.fr")
      token_url = "#{base_url}/oauth2/v3/token"

      response = HTTParty.post(
        token_url,
        headers: { "Content-Type" => "application/x-www-form-urlencoded" },
        body: {
          grant_type: "authorization_code",
          code: code,
          client_id: client_id,
          client_secret: client_secret,
          redirect_uri: redirect_uri
        }
      )

      unless response.success?
        Rails.logger.error("Erreur lors de l'échange du code: #{response.code} - #{response.body}")
        raise Enedis::ApiError.new(response.code, response.body)
      end

      token_data = JSON.parse(response.body)

      user.update(
        enedis_token: token_data["access_token"],
        enedis_token_expires_at: Time.current + token_data["expires_in"].to_i.seconds,
        enedis_refresh_token: token_data["refresh_token"]
      )

      token_data
    end
  end
end
