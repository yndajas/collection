class User < ApplicationRecord
  devise :two_factor_authenticatable,
         :database_authenticatable,
         :registerable,
         :recoverable,
         :rememberable,
         :validatable,
         otp_secret_encryption_key: Rails.application.credentials.otp_secret_encryption_key

  has_many :collectibles, dependent: :destroy
  has_many :labels, dependent: :destroy
  has_many :share_links, dependent: :destroy
  has_many :custom_sorts, dependent: :destroy

  has_many :granted_accesses,
           class_name: "ProfileAccess",
           foreign_key: :owner_id,
           dependent: :destroy
  has_many :received_accesses,
           class_name: "ProfileAccess",
           foreign_key: :viewer_id,
           dependent: :destroy
  has_many :allowlisted_viewers, through: :granted_accesses, source: :viewer

  # Collections this user follows. +follows_given+ are the join rows they own;
  # +follows_received+ are cleaned up when this user (a followed collection) is
  # destroyed.
  has_many :follows_given,
           class_name: "Follow",
           foreign_key: :follower_id,
           dependent: :destroy
  has_many :follows_received,
           class_name: "Follow",
           foreign_key: :followed_id,
           dependent: :destroy
  has_many :followed_collections, through: :follows_given, source: :followed

  COLLECTION_VIEWS = %w[cards list].freeze
  THEMES = %w[light dark monochrome_light monochrome_dark pastel_woodland pastel_parlour retro].freeze

  before_validation :assign_username, on: :create

  validates :username,
            uniqueness: { case_sensitive: false },
            allow_nil: true,
            format: { with: /\A[a-z0-9_-]+\z/, message: "may only contain lowercase letters, numbers, hyphens and underscores" }
  validates :collection_view, inclusion: { in: COLLECTION_VIEWS }
  validates :collections_sort, inclusion: { in: CollectionSearch::SORTS }
  validates :theme, inclusion: { in: THEMES }
  validate :collectibles_sort_is_known
  validate :hidden_default_sorts_are_known
  validate :hidden_link_keys_are_known

  # Look-up link keys this viewer wants to see, i.e. every link minus the ones
  # they've hidden. Applied wherever they view a collection, including their own.
  def visible_link_keys
    Collectible::LINK_KEYS - Array(hidden_link_keys)
  end

  # Options for the sort dropdown: built-in options the user hasn't hidden,
  # followed by each of their custom sorts. Never empty: if the user has hidden
  # every default and has no custom sorts, fall back to the default option so
  # collectible search always has at least one sort to offer.
  def sort_options
    defaults = CollectibleSearch::DEFAULT_OPTIONS
                 .reject { |key, _| Array(hidden_default_sorts).include?(key) }
                 .map { |key, label| [ label, key ] }
    options = defaults + custom_sorts.ordered.map { |sort| [ sort.display_name, sort.key ] }
    options.presence || [ CollectibleSearch.default_option ]
  end

  # { "custom-5" => [{ "field" =>, "direction" => }, ...], ... } for CollectibleSearch.
  def custom_sort_orders
    custom_sorts.each_with_object({}) { |sort, map| map[sort.key] = sort.criteria }
  end

  def to_param
    username
  end

  def name
    display_name.presence || username
  end

  # Collections +viewer+ (possibly nil) is allowed to see: every public
  # profile, plus (when signed in) their own collection and any private
  # collections shared with them. Returns a relation so callers can further
  # search, filter, and order it.
  def self.visible_to_viewer(viewer)
    public_scope = where(public_profile: true)
    return public_scope if viewer.nil?

    shared_owner_ids = ProfileAccess.where(viewer_id: viewer.id).select(:owner_id)
    public_scope.or(where(id: viewer.id)).or(where(id: shared_owner_ids))
  end

  # Whether this user follows +user+'s collection.
  def following?(user)
    follows_given.exists?(followed_id: user.id)
  end

  # Whether +viewer+ (possibly nil) can see this user's collection, optionally
  # via a share token.
  def visible_to?(viewer, token: nil)
    return true if public_profile?
    return false if viewer.nil? && token.blank?
    return true if viewer == self
    return true if viewer && allowlisted_viewers.exists?(viewer.id)
    return true if token.present? && share_links.active.exists?(token: token)

    false
  end

  private

  def collectibles_sort_is_known
    return if CollectibleSearch::SORTS.key?(collectibles_sort) || collectibles_sort.to_s.match?(/\Acustom-\d+\z/)

    errors.add(:collectibles_sort, "is not a known sort")
  end

  def hidden_default_sorts_are_known
    unknown = Array(hidden_default_sorts) - CollectibleSearch::DEFAULT_OPTIONS.keys
    errors.add(:hidden_default_sorts, "contains unknown options") if unknown.any?
  end

  def hidden_link_keys_are_known
    unknown = Array(hidden_link_keys) - Collectible::LINK_KEYS
    errors.add(:hidden_link_keys, "contains unknown links") if unknown.any?
  end

  def assign_username
    return if username.present?

    base = email.to_s.split("@").first.to_s.downcase.gsub(/[^a-z0-9_-]/, "-")
    base = "user" if base.blank?
    candidate = base
    suffix = 1
    while User.exists?(username: candidate)
      suffix += 1
      candidate = "#{base}-#{suffix}"
    end
    self.username = candidate
  end
end
