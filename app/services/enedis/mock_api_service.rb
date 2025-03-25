module Enedis
  class MockApiService
    include Enedis::DateValidation
    include Enedis::DataPersistence

    attr_reader :user, :auth_service

    def initialize(user)
      @user = user
      @auth_service = Enedis::AuthService.new(user)
    end

    # Récupère la consommation quotidienne sur une période (version mock)
    def get_daily_consumption(start_date, end_date)
      # Utilise la méthode prepare_date_range_params pour valider les dates
      params = prepare_date_range_params(start_date, end_date, "DAILY")

      # Génère des données de consommation fictives
      readings = []
      current_date = Date.parse(params[:start])
      end_date = Date.parse(params[:end])

      while current_date <= end_date
        value = rand(5..20).to_f
        readings << {
          "date" => current_date.to_s,
          "value" => value.to_s,
          "unit" => "kWh"
        }
        current_date += 1.day
      end

      # Structure de données compatible avec save_consumption_data
      data = {
        "meter_reading" => {
          "usage_point_id" => params[:usage_point_id],
          "reading_type" => {
            "measurement_kind" => "energy",
            "unit" => "kWh",
            "aggregate" => "DAILY"
          },
          "interval_reading" => readings
        }
      }

      # Utilise save_consumption_data du module DataPersistence
      save_consumption_data(data, "DAILY")
    end

    # Récupère la consommation mensuelle
    def get_monthly_consumption(start_date, end_date, period_type = "MONTHLY")
      max_months = 36
      # Calcul de la différence en mois entre les deux dates
      months_between = ((end_date.year - start_date.year) * 12) + (end_date.month - start_date.month)
      # Vérification et limitation de la période
      if months_between > max_months
        Rails.logger.warn("Période demandée (#{months_between} mois) trop longue, limitation à #{max_months} mois")
        start_date = end_date.months_ago(max_months).beginning_of_month
      end
      # Aligner les dates sur des mois complets
      start_date = start_date.beginning_of_month
      end_date = end_date.end_of_month

      # Récupérer d'abord les données quotidiennes (en spécifiant explicitement le type de période)
      get_daily_consumption(start_date, end_date)

      # Préparer la structure pour les données mensuelles
      monthly_data = {
        "meter_reading" => {
          "reading_type" => {
            "measurement_kind" => "energy",
            "unit" => "kWh",
            "aggregate" => "MONTHLY"
          },
          "interval_reading" => []
        }
      }

      # Agréger les données quotidiennes par mois
      daily_readings = user.energy_consumptions
      .where(measuring_period: "DAILY", date: start_date..end_date)
      .group("DATE_TRUNC('month', date), unit")
      .select("DATE_TRUNC('month', date) as month_date, SUM(value) as total_value, unit")

      # Conversion en format compatible avec save_consumption_data
      daily_readings.each do |reading|
        monthly_data["meter_reading"]["interval_reading"] << {
          "date" => reading.month_date.to_date.to_s,
          "value" => reading.total_value.to_s,
          "unit" => reading.unit
        }
      end

      # Utiliser la méthode existante pour sauvegarder les données
      save_consumption_data(monthly_data, "MONTHLY", "energy")
    end
  end
end
