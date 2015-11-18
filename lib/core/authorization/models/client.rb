class Client < ActiveRecord::Base
  belongs_to :role
  has_many :users, :through => :role
end