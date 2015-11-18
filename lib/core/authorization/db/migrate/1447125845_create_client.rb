class CreateClient < ActiveRecord::Migration 
  def change
    create_table :clients do |t|
      t.string :name, :required => true
      t.integer :role_id, :required => true
      t.string :private_key, :required => true
      t.string :public_key, :required => true
    end
  end
end