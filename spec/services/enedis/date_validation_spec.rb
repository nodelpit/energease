require 'rails_helper'

# Création d'une classe de test qui inclut le module DateValidation
class TestClass
  include Enedis::DateValidation
  attr_accessor :user

  def initialize(user)
    @user = user
  end
end

RSpec.describe Enedis::DateValidation, type: :service do
  # Crée un utilisateur avec un identifiant de point de consommation pour les tests
  let(:user) { create(:user, usage_point_id: "12345678901234") }
  # Initialise la classe de test qui inclut notre module
  let(:test_class) { TestClass.new(user) }

  describe "#ensure_date" do
    context "quand le paramètre est déjà un objet Date" do
      it "retourne l'objet Date sans modification" do
        # Prépare une date pour le test
        date = Date.today
        # Vérifie que la méthode retourne la même date sans modification
        expect(test_class.send(:ensure_date, date)).to eq(date)
      end
    end

    context "quand le paramètre est une chaîne de caractères au format ISO" do
      it "convertit correctement la chaîne en Date" do
        date_string = "2023-05-15"
        expected_date = Date.parse(date_string)
        expect(test_class.send(:ensure_date, date_string)).to eq(expected_date)
      end
    end

    context "quand le paramètre est une chaîne de caractères au format JJ/MM/AAAA" do
      it "convertit correctement la chaîne en Date" do
        date_string = "15/05/2023"
        expected_date = Date.parse(date_string)
        expect(test_class.send(:ensure_date, date_string)).to eq(expected_date)
      end
    end

    context "quand le paramètre répond à to_date" do
      it "utilise to_date pour convertir en Date" do
        time = Time.now
        expect(test_class.send(:ensure_date, time)).to eq(time.to_date)
      end
    end

    context "quand le format de la chaîne n'est pas reconnu" do
      it "lève une exception ArgumentError" do
        invalid_date = "non-date"
        expect { test_class.send(:ensure_date, invalid_date) }.to raise_error(ArgumentError, /Impossible de convertir en date/)
      end
    end

    context "quand le type de paramètre n'est pas pris en charge" do
      it "lève une exception ArgumentError" do
        invalid_type = 12345
        expect { test_class.send(:ensure_date, invalid_type) }.to raise_error(ArgumentError, /Impossible de convertir en date/)
      end
    end
  end

  describe "#validate_usage_point_id" do
    context "quand l'utilisateur a un point de consommation configuré" do
      it "retourne l'identifiant du point de consommation" do
        expect(test_class.send(:validate_usage_point_id)).to eq(user.usage_point_id)
      end
    end

    context "quand l'utilisateur n'a pas de point de consommation configuré" do
      # Crée un utilisateur sans point de consommation
      let(:user_without_point) { create(:user, usage_point_id: nil) }
      let(:class_test_without_point) { TestClass.new(user_without_point) }

      it "lève une exception ArgumentError" do
        expect { class_test_without_point.send(:validate_usage_point_id) }.to raise_error(ArgumentError, /L'utilisateur n'a pas de point de consommation configuré/)
      end
    end
  end

  describe "#validate_date_range" do
    context "quand les dates sont valides" do
      it "ne lève pas d'exception" do
        start_date = Date.today - 30.days
        end_date = Date.today

        # Vérifie que la méthode ne lève pas d'exception
        expect { test_class.send(:validate_date_range, start_date, end_date) }.not_to raise_error
      end
    end

    context "quand les dates ne sont pas des objets Date" do
      it "lève une exception ArgumentError" do
        start_date = "2025-01-01"
        end_date = Date.today

        expect { test_class.send(:validate_date_range, start_date, end_date) }.to raise_error(ArgumentError, /Les dates doivent être des objets Date/)
      end
    end

    context "quand la date de début est postérieure à la date de fin" do
      it "lève une exception ArgumentError" do
        start_date = Date.today
        end_date = Date.today - 10.days

        expect { test_class.send(:validate_date_range, start_date, end_date) }.to raise_error(ArgumentError, /La date de début .* doit être antérieure à la date de fin/)
      end
    end

    context "quand la date de début est dans le futur" do
      it "lève une exception ArgumentError" do
        start_date = Date.today + 1
        end_date = Date.today + 10.days

        expect { test_class.send(:validate_date_range, start_date, end_date) }.to raise_error(ArgumentError, /La date de début .* ne peut pas être dans le futur/)
      end
    end

    context "quand la période est trop longue pour le type DAILY" do
      it "lève une exception ArgumentError" do
        start_date = Date.today - 366.days
        end_date = Date.today

        expect { test_class.send(:validate_date_range, start_date, end_date) }.to raise_error(ArgumentError, /La période demandée .* est trop longue/)
      end
    end

    context "quand la période est trop longue pour le type MONTHLY" do
      it "lève une exception ArgumentError" do
        start_date = Date.today - 1096.days
        end_date = Date.today

        expect { test_class.send(:validate_date_range, start_date, end_date, "MONTHLY") }.to raise_error(ArgumentError, /La période demandée .* est trop longue/)
      end
    end

    context "quand la date de début est trop ancienne pour le type DAILY" do
      it "lève une exception ArgumentError" do
        # Plus de 36*30 jours dans le passé
        start_date = Date.today - (36*30 + 1).days
        end_date = start_date + 10.days

        expect { test_class.send(:validate_date_range, start_date, end_date) }.to raise_error(ArgumentError, /La date de début .* est trop ancienne/)
      end
    end

    context "quand la date de début est trop ancienne pour le type MONTHLY" do
      it "lève une exception ArgumentError" do
        # Plus de 1095 jours dans le passé
        start_date = Date.today - 1096.days
        end_date = start_date + 30.days

        expect { test_class.send(:validate_date_range, start_date, end_date, "MONTHLY") }.to raise_error(ArgumentError, /La date de début .* est trop ancienne/)
      end
    end
  end

  describe "#prepare_date_range_params" do
    context "quand les dates sont valides" do
      it "retourne un hash avec les paramètres formatés" do
        start_date = Date.today - 10.days
        end_date = Date.today

        result = test_class.send(:prepare_date_range_params, start_date, end_date)

        expect(result).to be_a(Hash)
        expect(result[:usage_point_id]).to eq(user.usage_point_id)
        expect(result[:start]).to eq(start_date.iso8601)
        expect(result[:end]).to eq(end_date.iso8601)
      end

      it "accepte un paramètre de type de période" do
        start_date = Date.today - 10.days
        end_date = Date.today

        result = test_class.send(:prepare_date_range_params, start_date, end_date, "MONTHLY")

        expect(result).to be_a(Hash)
        expect(result[:usage_point_id]).to eq(user.usage_point_id)
      end
    end

    context "quand les dates sont manquantes" do
      it "lève une exception ArgumentError" do
        expect { test_class.send(:prepare_date_range_params, nil, Date.today) }.to raise_error(
          ArgumentError, /Les dates de début et de fin sont requise/
        )

        expect { test_class.send(:prepare_date_range_params, Date.today, nil) }.to raise_error(
          ArgumentError, /Les dates de début et de fin sont requise/
        )
      end
    end

    context "quand les dates sont invalides" do
      it "lève une exception ArgumentError" do
        # Test avec une date de début dans le futur
        future_date = Date.today + 1.day

        expect { test_class.send(:prepare_date_range_params, future_date, future_date + 5.days) }.to raise_error(ArgumentError)
      end
    end

    context "quand l'utilisateur n'a pas de point de consommation" do
      let(:user_without_point) { create(:user, usage_point_id: nil) }
      let(:class_test_without_point) { TestClass.new(user_without_point) }

      it "lève une exception ArgumentError" do
        start_date = Date.today - 10.days
        end_date = Date.today

        expect { class_test_without_point.send(:prepare_date_range_params, start_date, end_date) }.to raise_error(
          ArgumentError, /L'utilisateur n'a pas de point de consommation configuré/
        )
      end
    end
  end
end
