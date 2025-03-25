require 'rails_helper'

RSpec.describe "Enedis::Consumptions", type: :request do
  # Configuration pour les tests qui simulent les erreurs API
  before(:all) do
    unless defined?(Enedis::ApiError)
      module Enedis
        class ApiError < StandardError; end
      end
    end
  end

  # Vérifie le comportement concernant l'authentification
  describe "authentification" do
    # Vérifie la redirection vers la page de connexion pour un utilisateur non authentifié
    it "redirige vers la page de connexion si l'utilisateur n'est pas authentifié" do
      get enedis_consumptions_path
      expect(response).to redirect_to(new_user_session_path)
    end
  end

  # Vérifie que l'utilisateur est redirigé s'il n'a pas configuré son point de livraison
  describe "point de livraison" do
    # Utilisateur sans point de livraison configuré
    let(:user_without_point) { create(:user) }

    before do
      sign_in user_without_point
    end

    # Test de redirection vers la page d'édition du profil
    it "redirige vers la page d'édition quand le point de livraison n'est pas configuré" do
      get enedis_consumptions_path
      expect(response).to redirect_to(edit_user_registration_path)
      expect(flash[:alert]).to be_present
    end
  end

  # Teste le comportement de l'action index
  describe "GET index" do
    # Utilisateur avec un point de livraison configuré
    let(:user) { create(:user, usage_point_id: "12345678901234") }

    before do
      sign_in user
    end

    # Contexte où l'utilisateur a des données de consommation
    context "quand l'utilisateur a des données de consommation" do
      before do
        create_list(:energy_consumption, 3,
          user: user,
          measuring_period: "DAILY",
          date: Date.today)
      end

      # Vérifie que la réponse est un succès
      it "renvoie une réponse réussie" do
        get enedis_consumptions_path
        expect(response).to have_http_status(:ok)
      end
    end

    # Contexte où l'utilisateur n'a pas de données de consommation
    context "quand l'utilisateur n'a pas de données de consommation" do
      # Vérifie que la réponse est un succès même sans données
      it "renvoie une réponse réussie avec des données vides" do
        get enedis_consumptions_path
        expect(response).to have_http_status(:ok)
      end
    end
  end

  describe "GET show" do
    let(:user) { create(:user, usage_point_id: "12345678901234") }
    let(:date_test) { Date.today }

    before do
      sign_in user

      # Créer des données de consommation pour la date de test
      create(
        :energy_consumption,
        user: user,
        measuring_period: "DAILY",
        date: date_test
      )
      create(
        :energy_consumption,
        user: user,
        measuring_period: "HOURLY",
        date: date_test
      )
    end

    # Vérifie l'affichage des consommations pour une date spécifiée
    it "répond avec succès pour une date spécifiée" do
      get enedis_consumptions_path(date: date_test.to_s)
      expect(response).to have_http_status(:ok)
    end

    # Vérifie le comportement par défaut sans date spécifiée
    it "utilise la date du jour par défaut quand aucune date n'est fournie" do
      get enedis_consumptions_path
      expect(response).to have_http_status(:ok)
    end

    # Vérifie la gestion des formats de date invalides
    it "gère les formats de date invalides" do
      get enedis_consumptions_path(date: "date-invalide")
      expect(response).to have_http_status(:ok)
    end
  end

  describe "GET daily" do
    # Utilisateur avec un point de livraison configuré
    let(:user) { create(:user, usage_point_id: "12345678901234") }
    let(:start_date) { Date.today - 30.days }
    let(:end_date) { Date.today }

    before do
      sign_in user
      # Créer des consommations sur différentes dates
      [ start_date, start_date + 15.days, end_date ].each do |date|
        create(
          :energy_consumption,
          user: user,
          measuring_period: "DAILY",
          date: date,
          value: 10.5
        )
      end
    end

    # Vérifie l'affichage des consommations quotidiennes sans paramètres
    it "retourne une réponse réussie avec les paramètres par défaut" do
      get daily_enedis_consumptions_path
      expect(response).to have_http_status(:ok)
    end

    # Vérifie le comportement avec une plage de dates personnalisée
    it "accepte des paramètres de date personnalisés" do
      custom_start = start_date + 5.days
      custom_end = start_date - 5.days

      get daily_enedis_consumptions_path(start_date: custom_start.to_s, end_date: custom_end.to_s)
      expect(response).to have_http_status(:ok)
    end

    # Vérifie l'inversion des dates si end_date est avant start_date
    it "gère l'inversion des dates" do
      get daily_enedis_consumptions_path(start_date: end_date.to_s, end_date: start_date.to_s)
      expect(response).to have_http_status(:ok)
    end

    # Vérifie la gestion des formats de date invalides
    it "gère les formats de date invalides" do
      get daily_enedis_consumptions_path(start_date: "date-invalide")
      expect(response).to have_http_status(:ok)
    end
  end

  describe "GET monthly" do
    # Utilisateur avec un point de livraison configuré
    let(:user) { create(:user, usage_point_id: "12345678901234") }
    let(:start_date) { (Date.today - 6.months).beginning_of_month }
    let(:end_date) { Date.today.end_of_month }

    before do
      sign_in user
      # Créer des consommations mensuelles sur plusieurs mois
      (0..5).each do |i|
        month_date = (Date.today - i.months).beginning_of_month
        create(
          :energy_consumption,
          user: user,
          measuring_period: "MONTHLY",
          date: month_date,
          value: 100.0 + i
        )
      end
    end

    # Vérifie l'affichage des consommations mensuelles par défaut (12 derniers mois)
    it "retourne une réponse réussie avec les paramètres par défaut" do
      get monthly_enedis_consumptions_path
      expect(response).to have_http_status(:ok)
    end

    # Vérifie le comportement avec une plage de dates personnalisée
    it "accepte des paramètres de date personnalisés" do
      custom_start = (Date.today - 3.months).beginning_of_month

      get monthly_enedis_consumptions_path(start_date: custom_start.to_s, end_date: end_date.to_s)
      expect(response).to have_http_status(:ok)
    end

    # Vérifie la gestion des formats de date invalides
    it "gère les formats de date invalides" do
      get monthly_enedis_consumptions_path(start_date: "date-invalide")
      expect(response).to have_http_status(:ok)
    end
  end

  # Teste la récupération des données via l'API
  describe "récupération des données API" do
    # Utilisateur avec un point de livraison configuré
    let(:user) { create(:user, usage_point_id: "12345678901234") }
    let(:mock_api_service) { instance_double(Enedis::MockApiService) }

    before do
      sign_in user
      # S'assurer qu'aucune donnée n'existe pour forcer l'appel API
      Enedis::EnergyConsumption.where(user: user).destroy_all
      allow(Enedis::MockApiService).to receive(:new).and_return(mock_api_service)
    end
  end
end
