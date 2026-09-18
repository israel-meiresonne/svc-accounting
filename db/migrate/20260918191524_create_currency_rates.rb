class CreateCurrencyRates < ActiveRecord::Migration[8.1]
  def change
    create_table :currency_rates do |t|
      t.string  :left, null: false
      t.string  :right, null: false
      t.decimal :rate, precision: 20, scale: 8, null: false
      t.timestamps
    end
    add_index :currency_rates, [ :left, :right ], unique: true
  end
end
