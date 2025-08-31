# frozen_string_literal: true

# User model representing application users
class User < ApplicationRecord
  # Associations
  has_many :posts, dependent: :destroy
  has_many :comments, through: :posts
  belongs_to :organization, optional: true

  # Validations
  validates :email, presence: true, uniqueness: true
  validates :name, presence: true
  validates :age, numericality: {greater_than: 0}, allow_nil: true

  # Scopes
  scope :active, -> { where(active: true) }
  scope :admins, -> { where(role: "admin") }
  scope :recent, -> { order(created_at: :desc) }

  # Callbacks
  before_save :normalize_email
  after_create :send_welcome_email

  # Instance methods
  def full_name
    "#{first_name} #{last_name}".strip
  end

  def admin?
    role == "admin"
  end

  def activate!
    update!(active: true, activated_at: Time.current)
  end

  private

  def normalize_email
    self.email = email.downcase.strip if email.present?
  end

  def send_welcome_email
    UserMailer.welcome(self).deliver_later
  end

  # Class methods
  class << self
    def find_by_email(email)
      find_by(email: email.downcase.strip)
    end

    def create_admin(attributes)
      create!(attributes.merge(role: "admin"))
    end
  end
end

# Modified for test