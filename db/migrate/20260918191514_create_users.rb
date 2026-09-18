class CreateUsers < ActiveRecord::Migration[8.1]
  def change
    create_table :users do |t|
      t.string   :code, null: false
      t.string   :type, null: false
      t.string   :first_name
      t.string   :last_name
      t.string   :company_name
      t.string   :email
      t.string   :password_digest
      t.string   :image
      t.string   :currency
      t.timestamps
    end
    add_index :users, :code, unique: true
    add_index :users, :email, unique: true
  end
end
