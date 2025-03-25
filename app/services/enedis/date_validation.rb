module Enedis
  module DateValidation
    def self.included(base)
      base.class_eval do
        private :prepare_date_range_params, :validate_date_range, :ensure_date, :validate_usage_point_id
      end
    end

    def prepare_date_range_params(start_date, end_date, period_type = "DAILY")
      # Vérification préliminaire des arguments
      raise ArgumentError, "Les dates de début et de fin sont requise" if start_date.nil? || end_date.nil?

      begin
        # Conversion des dates
        start_date = ensure_date(start_date)
        end_date = ensure_date(end_date)

        # Validation de la plage
        validate_date_range(start_date, end_date, period_type)

        # Récupération de l'identifiant du point de consommation
        usage_point_id = validate_usage_point_id

        # Construction et retour des paramètres
        {
          usage_point_id: usage_point_id,
          start: start_date.iso8601,
          end: end_date.iso8601
         }

      rescue => e
        # Capture et enrichit les erreurs
        Rails.logger.error("Erreur lors de la préparation des paramètres: #{e.message}")
        raise ArgumentError, "Impossible de préparer les paramètres de requête: #{e.message}"
      end
    end

    def validate_date_range(start_date, end_date, period_type = "DAILY")
      # Vérification du type de données
      raise ArgumentError, "Les dates doivent être des objets Date" unless start_date.is_a?(Date) && end_date.is_a?(Date)

      # Vérification chronologique avec message explicite
      raise ArgumentError, "La date de début (#{start_date}) doit être antérieure à la date de fin (#{end_date})" if start_date > end_date

      # Vérification du futur avec message contextuel
      raise ArgumentError, "La date de début (#{start_date}) ne peut pas être dans le futur" if start_date > Date.today

      # Définir la durée maximale en fonction du type de période
      max_days = period_type == "MONTHLY" ? 1095 : 365  # 3 ans pour les données mensuelles, 1 an pour les quotidiennes

      # Vérification de la durée
      duration = (end_date - start_date).to_i
      raise ArgumentError, "La période demandée (#{duration} jours) est trop longue (maximum: #{max_days} jours)" if duration > max_days

      # Vérification de l'ancienneté avec calcul direct
      max_history = period_type == "MONTHLY" ? 1095 : 36 * 30  # environ 36 mois
      raise ArgumentError, "La date de début (#{start_date}) est trop ancienne (maximum: #{max_history} jours)" if (Date.today - start_date).to_i > max_history
    end

    def ensure_date(date)
      return date if date.is_a?(Date)

      # Tente plusieurs formats de date possibles
      begin
        if date.is_a?(String)
          # Vérifie si le format semble valide avant de parser
          if date.match?(/^\d{4}-\d{2}-\d{2}$/) || date.match?(/^\d{2}\/\d{2}\/\d{4}$/)
            Date.parse(date)
          else
            raise ArgumentError, "Format de date non reconnu: #{date}"
          end
        elsif date.respond_to?(:to_date)
          date.to_date
        else
          raise ArgumentError, "Type de date non pris en charge: #{date.class}"
        end
      rescue => e
        Rails.logger.error("Erreur de conversion de date: #{e.message}")
        raise ArgumentError, "Impossible de convertir en date: #{date.inspect}"
      end
    end

    def validate_usage_point_id
      unless user.usage_point_id.present?
        raise ArgumentError, "L'utilisateur n'a pas de point de consommation configuré"
      end

      # Retourne l'identifiant du point de consommation
      user.usage_point_id
    end
  end
end
