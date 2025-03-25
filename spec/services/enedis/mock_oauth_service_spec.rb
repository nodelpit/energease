require 'rails_helper'

RSpec.describe Enedis::MockOauthService, type: :service do
  # Configuration globale des tests
  let(:user) { create(:user) }
  let(:mock_oauth_service) { described_class.new(user) }

  describe "#initialize" do
    it "initialise avec un utilisateur" do
      expect(mock_oauth_service.user).to eq(user)
    end
  end

  describe "#authorization_url" do
  it "retourne l'URL du callback mock avec un état" do
    # Définir un état spécifique pour le test
    state = "test_state_123"

    # Générer l'URL avec cet état
    url = mock_oauth_service.authorization_url(state: state)

    # Vérifier que l'URL contient le chemin de callback mock et le paramètre d'état
    expect(url).to include("/mock/oauth_callback")
    expect(url).to include("state=#{state}")
  end

  it "génère un état aléatoire si aucun n'est fourni" do
    # Générer l'URL sans spécifier d'état
    url = mock_oauth_service.authorization_url

    # Vérifier que l'URL contient le chemin de callback mock et un paramètre d'état
    expect(url).to include("/mock/oauth_callback")
    expect(url).to match(/state=[a-f0-9]{32}/)
  end
end

describe "#exchange_authorization_code" do
  let(:code) { "test_authorization_code" }
  let(:redirect_uri) { "http://example.com/callback" }
  let(:auth_service) { instance_double(Enedis::AuthService) }
  let(:token) { "test_access_token" }

  before do
    # Simuler le service d'authentification
    allow(Enedis::AuthService).to receive(:new).with(user).and_return(auth_service)
    allow(auth_service).to receive(:authenticate).and_return(token)
  end

  it "obtient un token via le service d'authentification" do
    # Vérifier que le service d'authentification est utilisé
    expect(auth_service).to receive(:authenticate)

    mock_oauth_service.exchange_authorization_code(code, redirect_uri)
  end

  it "met à jour les informations de token de l'utilisateur" do
    # Appeler la méthode
    mock_oauth_service.exchange_authorization_code(code, redirect_uri)

    # Recharger l'utilisateur et vérifier les mises à jour
    user.reload

    expect(user.enedis_token).to eq(token)
    expect(user.enedis_refresh_token).to be_nil
    expect(user.enedis_token_expires_at).to be_within(1.second).of(1.hour.from_now)
  end

  it "retourne un hash avec les informations du token" do
    # Appeler la méthode et capturer le résultat
    result = mock_oauth_service.exchange_authorization_code(code, redirect_uri)

    # Vérifier la structure et le contenu du résultat
    expect(result).to be_a(Hash)
    expect(result["access_token"]).to eq(token)
    expect(result["token_type"]).to eq("Bearer")
    expect(result["expires_in"]).to eq(3600)
  end
end
end
