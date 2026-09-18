class CreateAccounts < ActiveRecord::Migration[8.1]
  def change
    create_table :accounts do |t|
      t.string :code, null: false
      t.references :user, null: false, foreign_key: true
      t.string  :name, null: false
      t.string  :currency, null: false
      t.decimal :initial_balance, precision: 20, scale: 4
      t.decimal :balance_at_creation, precision: 20, scale: 4
      t.datetime :deleted_at
      t.timestamps
    end
    add_index :accounts, :code, unique: true
    add_index :accounts, :deleted_at
  end
end
