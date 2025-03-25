class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable

  has_many :energy_consumptions, class_name: "Enedis::EnergyConsumption"
  validates :usage_point_id, format: {
    with: /\A\d{14}\z/, message: "doit être un numéro à 14 chiffres" }, allow_blank: true
end
