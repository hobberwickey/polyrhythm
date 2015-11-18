class CreateRole < ActiveRecord::Migration 
  def change
    create_table :roles do |t|
      t.string :name, :required => true
    end
  end
end