require 'rails_helper'

RSpec.describe Enedis::OauthService, type: :service do
  # Configuration globale des tests
  let(:user) { create(:user) }
  let(:oauth_service) { described_class.new(user) }
  let(:client_id) { "test_client_id" }
  let(:client_secret) { "test_client_secret" }
  let(:base_url) { "https://api.test.enedis.fr" }

  before do
    # Stub les variables d'environnement
    allow(ENV).to receive(:fetch).with("ENEDIS_PUBLIC_KEY").and_return(client_id)
    allow(ENV).to receive(:fetch).with("ENEDIS_PRIVATE_KEY").and_return(client_secret)
    allow(ENV).to receive(:fetch).with("ENEDIS_API_BASE_URL", anything).and_return(base_url)
  end

  describe "#initialize" do
    it "initialise avec un utilisateur" do
      expect(oauth_service.user).to eq(user)
    end
  end

  describe "#authorization_url" do
    let(:callback_url) { "https://example.com/callback" }
    let(:state) { "test_state_123" }

    it "génère l'URL d'autorisation avec les paramètres fournis" do
      # Générer l'URL avec un état et un callback spécifiés
      url = oauth_service.authorization_url(callback_url: callback_url, state: state)

      # Vérifier que l'URL contient tous les éléments requis
      expect(url).to start_with(base_url)
      expect(url).to include("/dataconnect/v1/oauth2/authorize")
      expect(url).to include("client_id=#{client_id}")
      expect(url).to include("state=#{state}")
      expect(url).to include("response_type=code")
      expect(url).to include("redirect_uri=#{CGI.escape(callback_url)}")
    end

    it "génère un état aléatoire si aucun n'est fourni" do
      # Générer l'URL sans spécifier d'état
      url = oauth_service.authorization_url(callback_url: callback_url)

      # Vérifier que l'URL contient un paramètre d'état généré aléatoirement
      expect(url).to match(/state=[a-f0-9]{32}/)
    end
  end

  describe "#exchange_authorization_code" do
    let(:code) { "test_authorization_code" }
    let(:redirect_uri) { "https://example.com/callback" }
    let(:token_url) { "#{base_url}/oauth2/v3/token" }
    let(:token_response) do
      {
        "access_token" => "test_access_token",
        "refresh_token" => "test_refresh_token",
        "expires_in" => 3600,
        "token_type" => "Bearer"
      }
    end

    before do
      # Stub la requête HTTP pour le token
      stub_request(:post, token_url)
        .with(
          headers: { "Content-Type" => "application/x-www-form-urlencoded" },
          body: {
            grant_type: "authorization_code",
            code: code,
            client_id: client_id,
            client_secret: client_secret,
            redirect_uri: redirect_uri
          }
        )
        .to_return(
          status: 200,
          headers: { "Content-Type" => "application/json" },
          body: token_response.to_json
        )
    end

    it "échange le code contre un token" do
      result = oauth_service.exchange_authorization_code(code, redirect_uri)

      # Vérifier que le résultat contient les données du token
      expect(result).to eq(token_response)
    end

    it "met à jour les informations de token de l'utilisateur" do
      oauth_service.exchange_authorization_code(code, redirect_uri)

      # Recharger l'utilisateur et vérifier les mises à jour
      user.reload

      expect(user.enedis_token).to eq(token_response["access_token"])
      expect(user.enedis_refresh_token).to eq(token_response["refresh_token"])
      expect(user.enedis_token_expires_at).to be_within(1.second).of(Time.current + token_response["expires_in"].seconds)
    end

    context "quand la requête échoue" do
      before do
        # Stub une réponse d'erreur
        stub_request(:post, token_url)
          .to_return(
            status: 400,
            headers: { "Content-Type" => "application/json" },
            body: { error: "invalid_grant", error_description: "Invalid authorization code" }.to_json
          )
      end

      it "lève une ApiError" do
        expect { oauth_service.exchange_authorization_code(code, redirect_uri) }
          .to raise_error(Enedis::ApiError) do |error|
            expect(error.code).to eq(400)
            expect(error.body).to include("invalid_grant")
          end
      end
    end
  end
end
