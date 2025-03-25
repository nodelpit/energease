require 'rails_helper'

RSpec.describe Enedis::DataPersistence, type: :service do
  # Créer une classe factice qui inclut le module
  let(:test_class) do
    Class.new do
      include Enedis::DataPersistence

      attr_accessor :user

      def initialize(user)
        @user = user
      end
    end
  end

  let(:user) { create(:user, usage_point_id: "12345678901234") }
  let(:test_instance) { test_class.new(user) }

  describe "#save_consumption_data" do
    context "quand les données de lecture sont vides" do
      let(:empty_data) { {} }

      before do
        # Vérifier que le message est journalisé
        expect(Rails.logger).to receive(:info).with("Aucune donnée de consommation trouvée dans la réponse")
      end

      it "retourne nil" do
        result = test_instance.send(:save_consumption_data, empty_data, "DAILY")
        expect(result).to be_nil
      end
    end

    context "quand les données de lecture existent mais sont vides" do
      let(:empty_readings_data) { { "meter_reading" => { "interval_reading" => [] } } }

      before do
        # Vérifier que le message est journalisé
        expect(Rails.logger).to receive(:info).with("Aucune donnée de consommation trouvée dans la réponse")
      end

      it "retourne nil" do
        result = test_instance.send(:save_consumption_data, empty_readings_data, "DAILY")
        expect(result).to be_nil
      end
    end

    context "quand certaines lectures sont incomplètes" do
      let(:incomplete_readings_data) do
        {
          "meter_reading" => {
            "interval_reading" => [
              { "date" => "2025-03-01" }, # Manque value
              { "value" => "10.5" }, # Manque date
              { "date" => "2025-03-03", "value" => "15.2" } # Complet
            ]
          }
        }
      end

      before do
        # Vérifier que des avertissements sont journalisés
        expect(Rails.logger).to receive(:warn).with(/Donnée de lecture 0 incomplète/).once
        expect(Rails.logger).to receive(:warn).with(/Donnée de lecture 1 incomplète/).once
        expect(Rails.logger).to receive(:info).with("1 enregistrements de consommation sauvegardés")
      end

      it "ignore les lectures incomplètes et traite les lectures valides" do
        # Créer un mock pour la relation energy_consumptions
        energy_consumptions = double("EnergyConsumptions")
        consumption = double("EnergyConsumption", persisted?: true)

        # Configurer les attentes
        allow(user).to receive(:energy_consumptions).and_return(energy_consumptions)
        expect(energy_consumptions).to receive(:find_or_initialize_by).once.with(
          usage_point_id: user.usage_point_id,
          date: Date.parse("2025-03-03"),
          measuring_period: "DAILY"
        ).and_return(consumption)

        # Attendre que la méthode update soit appelée
        expect(consumption).to receive(:update).with(
          value: 15.2,
          unit: anything(), # On ne teste pas l'unité ici
          measurement_kind: "energy"
        )

        result = test_instance.send(:save_consumption_data, incomplete_readings_data, "DAILY")
        expect(result).to eq([ consumption ])
      end
    end
  end

  describe "#extract_unit" do
    context "quand aucune unité n'est spécifiée" do
      # Teste le comportement par défaut quand les données sont vides
      it "retourne l'unité par défaut (kWh)" do
        result = test_instance.send(:extract_unit, {}, {})
        expect(result).to eq("kWh")
      end
    end

    context "quand l'unité est spécifiée dans la lecture" do
      # Vérifie que l'unité est extraite directement de la lecture
      it "extrait l'unité de la lecture" do
        data = {}
        reading = { "unit" => "kW" }

        result = test_instance.send(:extract_unit, data, reading)
        expect(result).to eq("kW")
      end
    end

    context "quand l'unité est spécifiée dans les métadonnées" do
      # Vérifie l'extraction depuis les métadonnées quand la lecture n'a pas d'unité
      it "extrait l'unité des métadonnées" do
        data = { "meter_reading" => { "reading_type" => { "unit" => "VA" } } }
        reading = {}

        result = test_instance.send(:extract_unit, data, reading)
        expect(result).to eq("VA")
      end
    end

    context "quand l'unité a besoin d'être normalisée" do
      # Vérifie que la casse est préservée pour les unités valides
      it "conserve la casse des unités valides" do
        reading = { "unit" => "KWH" } # Majuscules

        result = test_instance.send(:extract_unit, {}, reading)
        expect(result).to eq("KWH")
      end

      # Vérifie que les unités non reconnues sont remplacées par la valeur par défaut
      it "remplace les unités invalides par kWh" do
        reading = { "unit" => "invalid_unit" }

        result = test_instance.send(:extract_unit, {}, reading)
        expect(result).to eq("kWh")
      end
    end

    context "quand une priorité doit être établie" do
      # Vérifie que l'unité de la lecture a priorité sur celle des métadonnées
      it "privilégie l'unité de la lecture par rapport aux métadonnées" do
        data = { "meter_reading" => { "reading_type" => { "unit" => "VA" } } }
        reading = { "unit" => "kW" }

        result = test_instance.send(:extract_unit, data, reading)
        expect(result).to eq("kW")
      end
    end
  end
end
