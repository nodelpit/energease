class CreateEnergyConsumptions < ActiveRecord::Migration[7.2]
  def change
    create_table :energy_consumptions do |t|
      t.references :user, null: false, foreign_key: true
      t.string :usage_point_id
      t.date :date
      t.float :value
      t.string :unit
      t.string :measuring_period
      t.string :measurement_kind

      t.timestamps
    end
  end
end
