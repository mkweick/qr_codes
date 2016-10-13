class Batch < ActiveRecord::Base
  belongs_to :event
  
  validates :number, presence: true,
    uniqueness: { scope: :event_id, case_sensitive: false}
  validates :description, presence: true
  validates :batch_type, presence: true

  def sorted_batches
    self.order(:created_at)
  end
end