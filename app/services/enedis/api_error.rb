module Enedis
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
