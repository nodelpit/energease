module Enedis
  module DataPersistence
    def self.included(base)
      base.class_eval do
        private :save_consumption_data, :extract_unit
      end
    end

    def save_consumption_data(data, period_type, measurement_kind = "energy")
      saved_records = []

      # Vérification de la présence des clés requises
      readings = data.dig("meter_reading", "interval_reading")

      # Si les lectures sont absentes ou vides, on journalise et on retourne un tableau vide
      return (Rails.logger.info("Aucune donnée de consommation trouvée dans la réponse") && []) unless readings.is_a?(Array) && readings.any?

      # Traitement de chaque lecture avec gestion des erreurs
      readings.each_with_index do |reading, index|
        begin
          # Vérification des données minimales requises
          unless reading.is_a?(Hash) && reading["date"].present? && reading["value"].present?
            Rails.logger.warn("Donnée de lecture #{index} incomplète: #{reading.inspect}")
            next
          end

          # Création/mise à jour de l'enregistrement
          consumption = user.energy_consumptions.find_or_initialize_by(
            usage_point_id: user.usage_point_id,
            date: Date.parse(reading["date"].to_s),
            measuring_period: period_type
          )

          # Mise à jour avec gestion des erreurs de conversion
          value = begin
            reading["value"].to_f
          rescue
            Rails.logger.warn("Impossible de convertir la valeur '#{reading["value"]}' en nombre")
            0.0
          end

          # Extraction sécurisée de l'unité
          unit = extract_unit(data, reading)

          # Mise à jour avec les valeurs validées
          consumption.update(
            value: value,
            unit: unit,
            measurement_kind: measurement_kind
          )

          # Vérification du succès de la sauvegarde
          saved_records << consumption and next if consumption.persisted?
          Rails.logger.error("Erreur lors de la sauvegarde: #{consumption.errors.full_messages.join(', ')}")
        rescue => e
          # Capture des erreurs pour chaque élément individuellement
          Rails.logger.error("Erreur lors du traitement de la lecture #{index}: #{e.message}")
        end
      end

      # Journalisation du résultat
      Rails.logger.info("#{saved_records.size} enregistrements de consommation sauvegardés")
      saved_records
    end

    def extract_unit(data, reading)
      unit = nil

      # Vérification défensive de la structure des objets
      return "kWh" unless data.is_a?(Hash) && reading.is_a?(Hash)

      # Tentative d'extraction de l'unité depuis la lecture
      if reading.key?("unit") && reading["unit"].is_a?(String) && !reading["unit"].empty?
        unit = reading["unit"]
      end

      # Si non trouvée, tentative d'extraction depuis les métadonnées
      if unit.nil? && data.dig("meter_reading", "reading_type", "unit").is_a?(String)
        unit = data["meter_reading"]["reading_type"]["unit"]
      end

      # Normalisation de l'unité
      unit = case unit&.downcase
      when "kwh", "kw", "kva", "w", "wh", "va"
        unit  # Unités valides
      else
        "kWh" # Valeur par défaut
      end

      unit
    end
  end
end
