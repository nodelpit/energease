require 'rails_helper'

RSpec.describe Enedis::ApiError, type: :service do
  describe "#initialize" do
    # Définir des valeurs de test
    let(:error_code) { 401 }
    let(:error_body) { '{"error":"unauthorized","error_description":"Invalid token"}' }
    let(:api_error) { described_class.new(error_code, error_body) }

    it "initialise avec un code et un corps d'erreur" do
      # Vérifie que les attributs sont correctement assignés
      expect(api_error.code).to eq(error_code)
      expect(api_error.body).to eq(error_body)
    end

    it "crée un message d'erreur formaté" do
      # Vérifie que le message d'erreur contient les informations attendues
      expected_message = "Erreur API Enedis (#{error_code}): #{error_body}"
      expect(api_error.message).to eq(expected_message)
    end
  end

  describe "héritage" do
    it "hérite de StandardError" do
      # Vérifie que l'erreur peut être attrapée comme une StandardError
      expect(Enedis::ApiError.ancestors).to include(StandardError)
    end
  end

  describe "utilisation pratique" do
    it "peut être levée et attrapée" do
      # Teste l'utilisation pratique de l'erreur dans un bloc begin/rescue
      expect {
        begin
          raise Enedis::ApiError.new(403, '{"error":"forbidden"}')
        rescue Enedis::ApiError => e
          # Vérifie que les attributs sont accessibles dans le bloc rescue
          expect(e.code).to eq(403)
          expect(e.body).to eq('{"error":"forbidden"}')
          raise e # Relève l'erreur pour le test
        end
      }.to raise_error(Enedis::ApiError)
    end

    it "peut être utilisée avec différents types de corps d'erreur" do
      # Test avec un corps d'erreur qui n'est pas une chaîne JSON
      html_error = described_class.new(500, "<html><body>Server Error</body></html>")
      expect(html_error.body).to include("Server Error")

      # Test avec un corps d'erreur simple (non structuré)
      text_error = described_class.new(429, "Too Many Requests")
      expect(text_error.body).to eq("Too Many Requests")
    end
  end
end
