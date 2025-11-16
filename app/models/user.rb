class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable, :confirmable,
         :omniauthable, omniauth_providers: [:google_oauth2]

  attr_accessor :skip_validation

  has_many :user_identities, dependent: :destroy

  validates :email, presence: true, uniqueness: true
  validates :uid, uniqueness: { scope: :provider }, allow_nil: true
  validates_presence_of :first_name, unless: :skip_validation
  validates_presence_of :last_name, unless: :skip_validation

  has_many :subscriptions, dependent: :destroy

  EARLY_ADOPTER = "early_adopter".freeze
  ADMIN = "admin"

  def self.from_omniauth(auth)
    where(provider: auth.provider, uid: auth.uid).first_or_create do |user|
      user.email = auth.info.email
      user.password = Devise.friendly_token[0,20]
      user.first_name = auth.info.first_name
      user.last_name = auth.info.last_name
      user.full_name = auth.info.name.titleize
      user.avatar_url = auth.info.image
      user.skip_confirmation!
      user.skip_validation = true
    end
  end

  def subscribed?
    subscriptions.where(status: ["active", "trailing"]).any? do |subscription|
      Time.now <= subscription.current_period_end
    end
  end

  def is_admin?
    self.role == ADMIN
  end

  # Allow users to sign in without password if they use social auth
  def password_required?
    provider.blank? && super
  end

  def superwall_user_id
    namespace_uuid = UUIDTools::UUID.parse(Rails.application.credentials[Rails.env.to_sym].dig(:superwall, :uuid))
    UUIDTools::UUID.sha1_create(namespace_uuid, self.id.to_s).to_s
  end
         
end
