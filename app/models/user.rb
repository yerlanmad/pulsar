class User < ApplicationRecord
  has_secure_password
  has_many :sessions, dependent: :destroy
  has_one :agent, dependent: :destroy

  normalizes :email_address, with: ->(e) { e.strip.downcase }

  enum :role, { agent: 0, supervisor: 1, admin: 2 }

  validates :name, presence: true
  validates :email_address, presence: true, uniqueness: true

  def admin? = role == "admin"
  def supervisor? = role == "supervisor"
  def agent? = role == "agent"
end
