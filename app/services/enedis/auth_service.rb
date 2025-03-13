require "httparty"

module Enedis
  class AuthService
    # URLs de base pour l'API Enedis
    BASE_URL = ENV.fetch("ENEDIS_API_BASE_URL", "https://gw.ext.prod-sandbox.api.enedis.fr")

    # URL pour l'obtention et la révocation de tokens
    TOKEN_URL = "#{BASE_URL}/oauth2/v3/token"
    REVOKE_URL = "#{BASE_URL}/oauth2/v3/revoke"

    attr_reader :user, :token, :token_expires_at

    def initialize(user)
      @user = user
      @token = user.enedis_token
      @token_expires_at = user.enedis_token_expires_at
    end

    # Vérifie si nous avons un token valide
    def authenticated?
      token.present? && token_expires_at.present? && token_expires_at > Time.current
    end

    # Obtenir un token d'accès avec l'authentification client credentials
    def authenticate
      client_id = ENV.fetch("ENEDIS_PUBLIC_KEY")
      client_secret = ENV.fetch("ENEDIS_PRIVATE_KEY")

      # Créer l'en-tête d'autorisation Basic
      auth_header = "Basic #{Base64.strict_encode64("#{client_id}:#{client_secret}")}"

      response = HTTParty.post(
        TOKEN_URL,
        headers: {
          "Content-Type" => "application/x-www-form-urlencoded",
          "Authorization" => auth_header
        },
        body: {
          grant_type: "client_credentials"
        }
      )

      # Vérifier si la requête a réussi
      # En cas d'échec, enregistrer l'erreur et lever une exception
      unless response.success?
        Rails.logger.error("Erreur d'authentification Enedis: #{response.code} - #{response.body}")
        raise ApiError.new(response.code, response.body)
      end

      # Parser la réponse
      parsed_response = JSON.parse(response.body)

      # Stocker le token et sa date d'expiration
      @token = parsed_response["access_token"]
      # La durée est généralement fournie en secondes dans la réponse
      @token_expires_at = Time.current + parsed_response["expires_in"].to_i.seconds

      # Mettre à jour l'utilisateur avec le nouveau token
      user.update(
        enedis_token: @token,
        enedis_token_expires_at: @token_expires_at
      )
      @token
    end

    # Révoquer le token d'accès
    def revoke_token
      return unless token.present?

      client_id = ENV.fetch("ENEDIS_PUBLIC_KEY")
      client_secret = ENV.fetch("ENEDIS_PRIVATE_KEY")

      # Créer l'en-tête d'autorisation Basic
      auth_header = "Basic #{Base64.strict_encode64("#{client_id}:#{client_secret}")}"

      response = HTTParty.post(
        REVOKE_URL,
        headers: {
          "Content-Type" => "application/x-www-form-urlencoded",
          "Authorization" => auth_header
        },
        body: {
          token: token,
          token_type_hint: "access_token"
        }
      )

      # Même si la révocation échoue, on supprime le token côté application
      user.update(
        enedis_token: nil,
        enedis_token_expires_at: nil
      )

      @token = nil
      @token_expires_at = nil

      response.success?
    end
  end

  # Gère les erreurs d'API en stockant le code HTTP et le message d'erreur
  class ApiError < StandardError
    attr_reader :code, :body

    def initialize(code, body)
      @code = code
      @body = body
      super("Erreur API Enedis (#{code}): #{body}")
    end
  end
end
