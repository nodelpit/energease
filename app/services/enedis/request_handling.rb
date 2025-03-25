module Enedis
  module RequestHandling
    def self.included(base)
      base.class_eval do
        private :make_api_request, :handle_response, :ensure_authenticated, :authorization_headers
      end
    end

    def make_api_request(method, url, options = {})
      # Vérifie que l'utilisateur est authentifié avant chaque requête
      ensure_authenticated

      # Ajoute les en-têtes d'autorisation aux options
      options[:headers] ||= {}
      options[:headers].merge!(authorization_headers)

      # Exécute la requête HTTP avec HTTParty
      HTTParty.send(method, url, options)
    end

    def handle_response(response)
      # Vérifie si la requête a échoué
      unless response.success?
        Rails.logger.error("Erreur API Enedis: #{response.code} - #{response.body}")
        raise Enedis::ApiError.new(response.code, response.body)
      end

      # Parse la réponse JSON
      parsed_response = JSON.parse(response.body)

      # Si un bloc est fourni, l'exécute avec les données et retourne son résultat
      if block_given?
        yield(parsed_response)
      else
        parsed_response
      end
    end

    def ensure_authenticated
      unless auth_service.authenticated?
        auth_service.authenticate
      end
    end

    def authorization_headers
      {
        "Accept" => "application/json",
        "Content-Type" => "application/json",
        "Authorization" => "Bearer #{user.enedis_token}"
      }
    end
  end
end
