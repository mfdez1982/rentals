class Note < ApplicationRecord
  belongs_to :landlord
  belongs_to :noteable, polymorphic: true, optional: true

  enum :status, { active: 0, completed: 1 }

  validates :title, presence: true
  validates :description, presence: true

  scope :active, -> { where(status: :active) }
  scope :completed, -> { where(status: :completed) }
  # Keep adjacent to #overdue? below — one is SQL (for querying), the other
  # in-memory (for a single loaded record); they must stay in sync.
  scope :overdue, -> { active.where("due_date < ?", Date.today).where.not(due_date: nil) }

  def activity?
    due_date.present?
  end

  def overdue?
    activity? && due_date.present? && due_date.past? && active?
  end

  def mark_complete!
    update!(status: :completed, completed_at: Time.current)
  end
end
