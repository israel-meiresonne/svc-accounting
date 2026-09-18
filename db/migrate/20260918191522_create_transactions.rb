class CreateTransactions < ActiveRecord::Migration[8.1]
  def change
    create_table :transactions do |t|
      t.string   :code, null: false
      t.references :account, null: false, foreign_key: true
      t.references :counterparty, null: false, foreign_key: { to_table: :users }
      t.decimal  :amount, precision: 20, scale: 4, null: false
      t.string   :currency, null: false
      t.string   :category
      t.text     :description
      t.string   :payment_method, null: false
      t.datetime :occurred_at, null: false
      t.string   :dedup_hash, null: false
      t.datetime :deleted_at
      t.timestamps
    end
    add_index :transactions, :code, unique: true
    add_index :transactions, :dedup_hash
    add_index :transactions, :deleted_at
    add_index :transactions, [ :account_id, :occurred_at ]
  end
end
