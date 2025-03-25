class Enedis::ConsumptionsController < ApplicationController
  before_action :authenticate_user!
  before_action :ensure_usage_point_configured

  # Dashboard des consommations
  def index
    @consumptions_by_day = current_user.energy_consumptions
      .where(measuring_period: "DAILY")
      .order(date: :desc)
      .limit(30)
      .group_by(&:date)

    # Garantir une réponse même sans données
    @consumptions_by_day = {} if @consumptions_by_day.empty?
  end

  # Détail journalier
  def show
    begin
      @date = params[:date].present? ? Date.parse(params[:date]) : Date.today
    rescue ArgumentError
      flash.now[:alert] = "Format de date invalide. Affichage de la date du jour."
      @date = Date.today
    end

    @consumptions = current_user.energy_consumptions
      .where(date: @date)
      .order(:measuring_period)
  end

  # Consommation quotidienne
  def daily
    # Parsing défensif des dates avec valeurs par défaut
    begin
      start_date = parse_date(params[:start_date], Date.today - 30.days)
      end_date = parse_date(params[:end_date], Date.today)
    rescue => e
      flash.now[:alert] = "Erreur lors du traitement des dates: #{e.message}"
      start_date = Date.today - 30.days
      end_date = Date.today
    end

    # Vérification de la cohérence des dates
    if end_date < start_date
      flash.now[:alert] = "La date de fin est antérieur a la date de début. Inversion des dates."
      start_date, end_date = end_date, start_date
    end

    # Récupération défensive des données
    fetch_data_if_needed("DAILY", start_date, end_date)

    # Préparation des données pour la vue
    @daily_consumption = current_user.energy_consumptions
      .where(measuring_period: "DAILY", date: start_date..end_date)
      .order(date: :desc)

    # Garantir des statistiques, même avec des données vides
    @total_consumption = @daily_consumption.sum(:value) || 0
    @average_consumption = @daily_consumption.any? ? @daily_consumption.average(:value) : 0
  end

  # Consommation mensuelle
  def monthly
    # Parsing défensif des dates
    begin
      start_date = parse_date(params[:start_date], (Date.today - 12.months).beginning_of_month)
      end_date = parse_date(params[:end_date], Date.today.end_of_month)
    rescue => e
      flash.now[:alert] = "Erreur lors du traitement des dates: #{e.message}"
      start_date = (Date.today - 12.months).beginning_of_month
      end_date = Date.today.end_of_month
    end

    # Récupération données
    fetch_data_if_needed("MONTHLY", start_date, end_date)

    @monthly_consumption = current_user.energy_consumptions
      .where(measuring_period: "MONTHLY", date: start_date..end_date)
      .order(date: :asc)

    Rails.logger.debug "Nombre de labels: #{@monthly_consumption.count}"
    Rails.logger.debug "Labels: #{@monthly_consumption.map { |c| l(c.date, format: '%b %Y') }}"
    Rails.logger.debug "Valeurs: #{@monthly_consumption.map(&:value)}"

    @total_consumption = @monthly_consumption.sum(:value) || 0
    @average_consumption = @monthly_consumption.any? ? @monthly_consumption.average(:value).to_f : 0
    @months_count = @monthly_consumption.count
  end

  private

  # Vérifie que l'utilisateur a un point de consommation configuré
  def ensure_usage_point_configured
    return if current_user.usage_point_id.present?

    flash[:alert] = "Veuillez configurer votre point de livraison Enedis pour accéder à vos données."
    redirect_to edit_user_registration_path
  end

  # Parsing sécurisé des dates avec valeur par défaut
  def parse_date(date_param, default_date)
    return default_date unless date_param.present?

    begin
      Date.parse(date_param.to_s)
    rescue ArgumentError
      raise ArgumentError, "Format de date invalide: #{date_param}"
    end
  end

  # Récupération des données via l'API si nécessaire
  def fetch_data_if_needed(period_type, start_date, end_date)
    return if current_user.energy_consumptions.where(measuring_period: period_type, date: start_date..end_date).exists?

    begin
      # Utilise automatiquement le bon service selon l'environnement
      api_service = EnedisApiService.new(current_user)

      case period_type
      when "DAILY"
        api_service.get_daily_consumption(start_date, end_date)
      when "MONTHLY"
        api_service.get_monthly_consumption(start_date, end_date, period_type)
      end
    rescue Enedis::ApiError => e
      flash.now[:alert] = "Impossible de récupérer vos données de consommation: #{e.message}"
      Rails.logger.error("Erreur API pour l'utilisateur #{current_user.id}: #{e.message}")
    rescue => e
      flash.now[:alert] = "Une erreur est survenue lors de la récupération des données."
      Rails.logger.error("Erreur imprévue: #{e.class} - #{e.message}")
    end
  end
end
