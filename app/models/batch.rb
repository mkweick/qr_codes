class Batch < ActiveRecord::Base
  belongs_to :event
  validates :description, presence: true

  
end