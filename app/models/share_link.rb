class ShareLink < ApplicationRecord
  belongs_to :user

  before_validation :assign_token, on: :create

  validates :token, presence: true, uniqueness: true

  scope :active, -> { where("expires_at IS NULL OR expires_at > ?", Time.current) }

  def expired?
    expires_at.present? && expires_at <= Time.current
  end

  private

  def assign_token
    self.token ||= SecureRandom.urlsafe_base64(16)
  end
end
