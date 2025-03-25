require 'rails_helper'

RSpec.describe Enedis::MockApiService, type: :service do
  # Configuration globale des tests
  let(:user) { create(:user, usage_point_id: "12345678901234") }
  let(:mock_api_service) { described_class.new(user) }

  describe "#initialize" do
    it "initialise avec un utilisateur et crée un auth_service" do
      expect(mock_api_service.user).to eq(user)
      expect(mock_api_service.auth_service).to be_a(Enedis::AuthService)
      expect(mock_api_service.auth_service.user).to eq(user)
    end
  end

  describe "#get_daily_consumption" do
    let(:start_date) { Date.today - 7.days }
    let(:end_date) { Date.today }

    it "génère des données quotidiennes pour chaque jour de la période" do
      # Capture les données générées avant qu'elles ne soient sauvegardées
      expect(mock_api_service).to receive(:save_consumption_data) do |data, period_type|
        # Vérifie que la période est correcte
        expect(period_type).to eq("DAILY")

        # Vérifie que les données ont la structure attendue
        expect(data).to have_key("meter_reading")
        expect(data["meter_reading"]).to have_key("interval_reading")

        # Vérifie que le nombre de lectures correspond au nombre de jours
        interval_readings = data["meter_reading"]["interval_reading"]
        expected_days = (end_date - start_date).to_i + 1
        expect(interval_readings.length).to eq(expected_days)

        # Vérifie que les lectures contiennent les bonnes dates
        dates = interval_readings.map { |r| Date.parse(r["date"]) }
        expect(dates).to include(start_date)
        expect(dates).to include(end_date)

        # Vérifie que les valeurs sont des nombres entre 5 et 20
        values = interval_readings.map { |r| r["value"].to_f }
        expect(values.all? { |v| v >= 5 && v <= 20 }).to be true

        # Vérifie que l'unité est kWh
        units = interval_readings.map { |r| r["unit"] }.uniq
        expect(units).to eq([ "kWh" ])
      end

      mock_api_service.get_daily_consumption(start_date, end_date)
    end
  end

  describe "#get_monthly_consumption" do
  let(:start_date) { Date.today - 60.days }
  let(:end_date) { Date.today }

  before do
    # Stub get_daily_consumption pour qu'il n'appelle pas réellement la méthode
    allow(mock_api_service).to receive(:get_daily_consumption)

    # Stub les requêtes SQL pour les tests unitaires
    daily_readings = [
      double("Reading", month_date: (Date.today - 2.months).beginning_of_month, total_value: 150.0, unit: "kWh"),
      double("Reading", month_date: (Date.today - 1.month).beginning_of_month, total_value: 200.0, unit: "kWh")
    ]

    consumptions_relation = double("ActiveRecord::Relation")
    allow(consumptions_relation).to receive(:where).and_return(consumptions_relation)
    allow(consumptions_relation).to receive(:group).and_return(consumptions_relation)
    allow(consumptions_relation).to receive(:select).and_return(daily_readings)

    allow(user).to receive(:energy_consumptions).and_return(consumptions_relation)

    # Stub save_consumption_data pour vérifier les données
    allow(mock_api_service).to receive(:save_consumption_data)
  end

  it "appelle get_daily_consumption pour obtenir les données quotidiennes" do
    # Vérifie que get_daily_consumption est appelé avec les bonnes dates
    expect(mock_api_service).to receive(:get_daily_consumption) do |s_date, e_date|
      expect(s_date).to eq(start_date.beginning_of_month)
      expect(e_date).to eq(end_date.end_of_month)
    end

    mock_api_service.get_monthly_consumption(start_date, end_date)
  end

  it "limite la période à 36 mois si nécessaire" do
    long_start_date = Date.today - 40.months

    expect(mock_api_service).to receive(:get_daily_consumption) do |s_date, e_date|
      # Vérifie que la date de début est limitée à 36 mois dans le passé
      months_diff = ((e_date.year - s_date.year) * 12) + e_date.month - s_date.month
      expect(months_diff).to be <= 36
    end

    mock_api_service.get_monthly_consumption(long_start_date, end_date)
  end

  it "agrège les données quotidiennes par mois" do
    expect(mock_api_service).to receive(:save_consumption_data) do |data, period_type, kind|
      # Vérifie que les paramètres sont corrects
      expect(period_type).to eq("MONTHLY")
      expect(kind).to eq("energy")

      # Vérifie la structure des données
      expect(data).to have_key("meter_reading")
      expect(data["meter_reading"]).to have_key("interval_reading")

      # Vérifie que les lectures mensuelles sont présentes
      monthly_readings = data["meter_reading"]["interval_reading"]
      expect(monthly_readings.length).to eq(2) # Nous avons mockés deux mois de données

      # Vérifie que les valeurs sont correctes
      values = monthly_readings.map { |r| r["value"].to_f }
      expect(values).to include(150.0, 200.0)

      # Vérifie que l'unité est correcte
      units = monthly_readings.map { |r| r["unit"] }.uniq
      expect(units).to eq([ "kWh" ])
    end

    mock_api_service.get_monthly_consumption(start_date, end_date)
  end
end
end
