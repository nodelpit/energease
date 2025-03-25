require 'rails_helper'

# Créer une classe de test qui inclut le module RequestHandling
class TestRequestHandling
  include Enedis::RequestHandling
  attr_reader :user, :auth_service

  def initialize(user, auth_service)
    @user = user
    @auth_service = auth_service
  end
end

RSpec.describe Enedis::RequestHandling, type: :service do
  # Configuration globale des tests
  let(:user) { create(:user, enedis_token: "test_token") }
  let(:auth_service) { instance_double(Enedis::AuthService) }
  let(:test_class) { TestRequestHandling.new(user, auth_service) }

  # Permettre l'accès aux méthodes privées pour les tests
  before do
    # Autoriser l'invocation des méthodes privées
    TestRequestHandling.class_eval do
      public :make_api_request, :handle_response, :ensure_authenticated, :authorization_headers
    end
  end

  describe "#authorization_headers" do
    it "retourne les en-têtes avec le token d'autorisation" do
      headers = test_class.authorization_headers

      expect(headers).to be_a(Hash)
      expect(headers["Authorization"]).to eq("Bearer test_token")
      expect(headers["Accept"]).to eq("application/json")
      expect(headers["Content-Type"]).to eq("application/json")
    end
  end

  describe "#ensure_authenticated" do
    context "quand l'utilisateur est déjà authentifié" do
      before do
        allow(auth_service).to receive(:authenticated?).and_return(true)
      end

      it "ne tente pas de l'authentifier à nouveau" do
        expect(auth_service).not_to receive(:authenticate)
        test_class.ensure_authenticated
      end
    end

    context "quand l'utilisateur n'est pas authentifié" do
      before do
        allow(auth_service).to receive(:authenticated?).and_return(false)
        allow(auth_service).to receive(:authenticate)
      end

      it "l'authentifie" do
        expect(auth_service).to receive(:authenticate)
        test_class.ensure_authenticated
      end
    end
  end

  describe "#handle_response" do
    context "quand la réponse est un succès" do
      let(:response) do
        instance_double(
          HTTParty::Response,
          success?: true,
          body: '{"data":{"value":"test"}}'
        )
      end

      it "parse la réponse JSON" do
        result = test_class.handle_response(response)
        expect(result).to eq({ "data" => { "value" => "test" } })
      end

      it "utilise le bloc si fourni" do
        result = test_class.handle_response(response) { |data| data["data"]["value"] }
        expect(result).to eq("test")
      end
    end

    context "quand la réponse est un échec" do
      let(:response) do
        instance_double(
          HTTParty::Response,
          success?: false,
          code: 401,
          body: '{"error":"invalid_token"}'
        )
      end

      before do
        allow(Rails.logger).to receive(:error)
      end

      it "lève une ApiError" do
        expect { test_class.handle_response(response) }.to raise_error(Enedis::ApiError) do |error|
          expect(error.code).to eq(401)
          expect(error.body).to eq('{"error":"invalid_token"}')
        end
      end

      it "enregistre l'erreur dans les logs" do
        expect(Rails.logger).to receive(:error).with(/Erreur API Enedis: 401/)

        begin
          test_class.handle_response(response)
        rescue Enedis::ApiError
          # On attrape l'exception pour ne pas faire échouer le test
        end
      end
    end
  end

  describe "#make_api_request" do
    let(:url) { "https://api.example.com/data" }
    let(:options) { { query: { param: "value" } } }
    let(:headers) { { "Authorization" => "Bearer test_token", "Accept" => "application/json", "Content-Type" => "application/json" } }

    before do
      allow(test_class).to receive(:ensure_authenticated)
      allow(test_class).to receive(:authorization_headers).and_return(headers)
      allow(HTTParty).to receive(:get).and_return(double("response"))
    end

    it "s'assure que l'utilisateur est authentifié" do
      expect(test_class).to receive(:ensure_authenticated)
      test_class.make_api_request(:get, url)
    end

    it "ajoute les en-têtes d'autorisation aux options" do
      expected_options = { headers: headers, query: { param: "value" } }

      expect(HTTParty).to receive(:get).with(url, hash_including(expected_options))
      test_class.make_api_request(:get, url, options)
    end

    it "exécute la requête HTTP avec la méthode spécifiée" do
      expect(HTTParty).to receive(:get).with(url, anything)
      test_class.make_api_request(:get, url)

      allow(HTTParty).to receive(:post).and_return(double("response"))
      expect(HTTParty).to receive(:post).with(url, anything)
      test_class.make_api_request(:post, url)
    end

    it "fusionne les en-têtes existants avec les en-têtes d'autorisation" do
      existing_headers = { "Custom-Header" => "Value" }
      options_with_headers = { headers: existing_headers }

      expected_headers = existing_headers.merge(headers)

      expect(HTTParty).to receive(:get).with(url, hash_including(headers: expected_headers))
      test_class.make_api_request(:get, url, options_with_headers)
    end
  end
end
