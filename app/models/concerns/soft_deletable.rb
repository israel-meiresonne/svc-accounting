module SoftDeletable
  extend ActiveSupport::Concern

  RETENTION_PERIOD = 30.days

  included do
    scope :active, -> { where(deleted_at: nil) }
  end

  def soft_delete!
    update!(deleted_at: Time.current)
  end
end
