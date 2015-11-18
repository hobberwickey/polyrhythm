class CreateUserRole < ActiveRecord::Migration 
  def change
    create_table :user_roles do |t|
      t.integer :user_id, :required => true
      t.integer :role_id, :required => true
    end
  end
end