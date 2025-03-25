module Enedis
  class ApiService
    include Enedis::DateValidation
    include Enedis::RequestHandling
    include Enedis::DataPersistence

    # URLs pour l'API Enedis
    BASE_URL = ENV.fetch("ENEDIS_API_BASE_URL", "https://gw.ext.prod-sandbox.api.enedis.fr")

    # URLs spécifiques pour chaque service
    URLS =  {
      daily_consumption: "#{BASE_URL}/metering_data_dc/v5/daily_consumption",
      consumption_load_curve: "#{BASE_URL}/metering_data_clc/v5/consumption_load_curve",
      daily_consumption_max_power: "#{BASE_URL}/metering_data_dcmp/v5/daily_consumption_max_power",
      production_load_curve: "#{BASE_URL}/metering_data_plc/v5/production_load_curve",
      daily_production: "#{BASE_URL}/metering_data_dp/v5/daily_production",
      addresses: "#{BASE_URL}/customers_upa/v5/usage_points/addresses",
      contracts: "#{BASE_URL}/customers_upc/v5/usage_points/contracts",
      identity: "#{BASE_URL}/customers_i/v5/identity",
      contact_data: "#{BASE_URL}/customers_cd/v5/contact_data"
    }

    # Endpoint d'autorisation OAuth2
    OAUTH_AUTHORIZE_URL = "#{BASE_URL}/dataconnect/v1/oauth2/authorize"

    attr_reader :user, :auth_service

    def initialize(user)
      @user = user
      @auth_service = Enedis::AuthService.new(user)
    end

    #=== Méthodes pour les données de consommation ===#

    # Récupère la consommation quotidienne sur une période
    def get_daily_consumption(start_date, end_date)
      params = prepare_date_range_params(start_date, end_date)

      response = make_api_request(
        :get,
        URLS[:daily_consumption],
        query: params
      )
      handle_response(response) do |data|
        save_consumption_data(data, "DAILY")
      end
    end

    # Récupère la consommation mensuelle sur une période
    def get_monthly_consumption(start_date, end_date)
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
      end_date = end_date.beginning_of_month

      # Récupérer d'abord les données quotidiennes
      # Passer "DAILY" explicitement pour respecter sa limite
      prepare_date_range_params(start_date, end_date, "DAILY")

      # Récupérer d'abord les données quotidiennes
      get_daily_consumption(start_date, end_date)

      # Préparer la structure pour les données mensuelles
      monthly_data = {
        "meter_reading" => {
          "interval_reading" => []
        }
      }

      # Agréger les données quotidiennes par mois
      daily_readings = user.energy_consumptions
      .where(measuring_period: "DAILY", date: start_date..end_date)
      .group("DATE_TRUNC('month', date)")
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

    # Récupère les données de consommation toutes les 30 min
    def get_consumption_load_curve(start_date, end_date)
      params = prepare_date_range_params(start_date, end_date)

      response = make_api_request(
        :get,
        URLS[:consumption_load_curve],
        query: params
      )

      handle_response(response) do |data|
        save_consumption_data(data, "THIRTY_MINUTES", "power")
      end
    end

    # Récupère la puissance maximale quotidienne sur une période
    def get_daily_consumption_max_power(start_date, end_date)
      params = prepare_date_range_params(start_date, end_date, "DAILY")

      response = make_api_request(
        :get,
        URLS[:daily_consumption_max_power],
        query: params
      )

      handle_response(response) do |data|
        save_consumption_data(data, "DAILY", "power_max")
      end
    end

    # Récupère la production quotidienne sur une période
    def get_daily_production(start_date, end_date)
      params = prepare_date_range_params(start_date, end_date)

      response = make_api_request(
        :get,
        URLS[:daily_production],
        query: params
      )

      handle_response(response) do |data|
        save_consumption_data(data, "DAILY", "production")
      end
    end

    # Pour récupérer les informations du point de consommation
    def get_usage_point_info
      params = { usage_point_id: user.usage_point_id }

      response = make_api_request(
        :get,
        URLS[:addresses],
        query: params
      )

      handle_response(response)
    end

    # Récupère les informations de contrat du point de consommation
    def get_contracts
      params = { usage_point_id: user.usage_point_id }

      response = make_api_request(
        :get,
        URLS[:contracts],
        query: params
      )

      handle_response(response)
    end
  end
end
