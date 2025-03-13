require 'rails_helper'

RSpec.describe Enedis::AuthService do
  describe "#initialize" do
    # Crée un utilisateur avec un token valide pour les tests
    let(:user) { create(:user, :with_valid_token) }
    # Crée une instance du service avec l'utilisateur
    let(:auth_service) { described_class.new(user) }

    it "initialise avec un utilisateur" do
      # Vérifie que les attributs sont correctement initialisés
      expect(auth_service.user).to eq(user)
      expect(auth_service.token).to eq(user.enedis_token)
      expect(auth_service.token_expires_at).to eq(user.enedis_token_expires_at)
    end
  end

  describe "#authenticated?" do
    # Crée une instance du service pour les tests
    let(:auth_service) { described_class.new(user) }

    context "quand le token est valide" do
      # Utilise un utilisateur avec un token non expiré
      let(:user) { create(:user, :with_valid_token) }

      it "retourne true" do
        expect(auth_service.authenticated?).to be true
      end
    end

    context 'quand le token est manquant' do
      # Utilise un utilisateur sans token
      let(:user) { create(:user) }

      it "retourne false" do
        expect(auth_service.authenticated?).to be false
      end
    end

    context 'quand le token est expiré' do
      # Utilise un utilisateur avec un token expiré
      let(:user) { create(:user, :with_expired_token) }

      it "retourne false" do
        expect(auth_service.authenticated?).to be false
      end
    end
  end

  describe "#authenticate" do
    # Prépare les données pour les tests d'authentification
    let(:user) { create(:user) }
    let(:auth_service) { described_class.new(user) }
    let(:client_id) { "test_client_id" }
    let(:client_secret) { "test_client_secret" }
    let (:token_url) { "#{described_class::BASE_URL}/oauth2/v3/token" }

    before do
      # Simule les variables d'environnement pour les tests
      allow(ENV).to receive(:fetch).with("ENEDIS_PUBLIC_KEY").and_return(client_id)
      allow(ENV).to receive(:fetch).with("ENEDIS_PRIVATE_KEY").and_return(client_secret)
    end

    context "quand l'authentification réussit" do
      before do
        # Simule une réponse réussie de l'API Enedis
        stub_request(:post, token_url).with(
          headers: {
            "Content-Type" => "application/x-www-form-urlencoded",
            "Authorization" => /Basic .+/
          }
        ).to_return(
          status: 200,
          headers: { "Content-Type" => "application/json" },
          body: {
            access_token: "new_token",
            expires_in: 3600
          }.to_json
        )
      end

      it "obtient un token et met à jour l'utilisateur" do
        token = auth_service.authenticate

        # Vérifie que le token est retourné et persisté en base
        expect(token).to eq("new_token")
        expect(user.reload.enedis_token).to eq("new_token")
        # Vérifie que la date d'expiration est correcte à 1 seconde près
        expect(user.enedis_token_expires_at).to be_within(1.second).of(Time.current + 3600.seconds)
      end
    end

    context "quand l'authentification échoue" do
      # Simule une réponse d'erreur de l'API Enedis
      before do
        stub_request(:post, token_url).with(
          headers: {
            "Content-Type" => "application/x-www-form-urlencoded",
            "Authorization" => /Basic .+/
           }
        ).to_return(
          status: 401,
          headers: { "Content-Type" => "application/json" },
          body: {
          error: "invalid_client",
          error_description: "Client authentication failed"
          }.to_json
        )
      end

      it "lève une ApiError" do
        # Vérifie que l'exception est levée avec les bonnes propriétés
        expect { auth_service.authenticate }.to raise_error(Enedis::ApiError) do |error|
          expect(error.code).to eq(401)
          expect(error.body).to include("invalid_client")
        end
      end
    end
  end

  describe "#revoke_token" do
    # Prépare les données pour les tests de révocation
    let(:user) { create(:user, :with_valid_token) }
    let(:auth_service) { described_class.new(user) }
    let(:client_id) { "test_client_id" }
    let(:client_secret) { "test_client_secret" }
    let(:revoke_url) { "#{described_class::BASE_URL}/oauth2/v3/revoke" }

    before do
      # Simule les variables d'environnement pour les tests
      allow(ENV).to receive(:fetch).with("ENEDIS_PUBLIC_KEY").and_return(client_id)
      allow(ENV).to receive(:fetch).with("ENEDIS_PRIVATE_KEY").and_return(client_secret)
    end

    context "quand le token existe" do
      # Simule une réponse réussie de l'API pour la révocation
      before do
        stub_request(:post, revoke_url).with(
          headers: {
            "Content-Type" => "application/x-www-form-urlencoded",
            "Authorization" => /Basic .+/
           }
        ).to_return(
          status: 200,
          body: ""
        )
      end

      it "révoque le token et met à jour l'utilisateur" do
        result = auth_service.revoke_token

        # Vérifie que la méthode retourne true et que le token est supprimé
        expect(result).to be true
        expect(user.reload.enedis_token).to be_nil
        expect(user.enedis_token_expires_at).to be_nil
      end
    end

    context "quand le token n'existe pas" do
      # Utilise un utilisateur sans token
      let(:user) { create(:user) }

      it "retourne rapidement sans faire de requête" do
        # Vérifie qu'aucune requête HTTP n'est effectuée
        expect(HTTParty).not_to receive(:post)

        result = auth_service.revoke_token
        expect(result).to be_nil
      end
    end
  end
end
