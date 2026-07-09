class Note < ApplicationRecord
  belongs_to :landlord
  belongs_to :noteable, polymorphic: true, optional: true

  enum :status, { active: 0, completed: 1 }

  validates :landlord_id, presence: true
  validates :title, presence: true
  validates :description, presence: true
  validates :status, presence: true

  scope :active, -> { where(status: :active) }
  scope :completed, -> { where(status: :completed) }
  scope :overdue, -> { active.where("due_date < ?", Date.today).where.not(due_date: nil) }

  def activity?
    due_date.present?
  end

  def overdue?
    activity? && due_date < Date.today && active?
  end

  def mark_complete!
    update!(status: :completed, completed_at: Time.current)
  end
end
