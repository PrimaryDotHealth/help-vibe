# A conversation (or later, a ticket) with a contact. Table: threads.
# Parts are its messages, notes and events, in order.
class SupportThread < ApplicationRecord
  self.table_name = "threads"

  STATES = %w[open snoozed closed].freeze
  PRIORITIES = %w[none low medium high urgent].freeze

  belongs_to :contact, optional: true
  belongs_to :assignee_user, class_name: "User", optional: true
  belongs_to :assignee_team, class_name: "Team", optional: true
  has_many :parts, -> { order(:id) }, class_name: "ThreadPart", foreign_key: :thread_id, dependent: :destroy, inverse_of: :thread
  has_many :reads, class_name: "ThreadRead", foreign_key: :thread_id, dependent: :delete_all
  has_many :thread_tags, foreign_key: :thread_id, dependent: :delete_all
  has_many :tags, through: :thread_tags

  validates :state, inclusion: { in: STATES }
  validates :priority, inclusion: { in: PRIORITIES }

  before_validation(on: :create) { self.reply_token ||= SecureRandom.base58(24) }

  # Contacts open their conversation from an email link without signing in.
  generates_token_for :contact_link, expires_in: 30.days

  # Agents' inbox lists refresh themselves (Turbo 8 morph) when a thread changes.
  after_commit -> { broadcast_refresh_later_to "inbox" }

  scope :open_state, -> { where(state: "open") }
  scope :waiting_first, -> { order(Arel.sql("waiting_since asc nulls last, updated_at desc")) }

  def to_param = number.to_s
  def title_or_preview = title.presence || parts.find { _1.kind == "comment" }&.body.to_s.truncate(80)

  # Ruby mirror of the threads_agent RLS policy, used for authorization.
  def self.visible_to_agent(user)
    return all if user.admin? || user.permissions.include?("see_all_threads")
    where(assignee_user_id: user.id).or(where(assignee_team_id: user.team_ids)).or(where(assignee_user_id: nil, assignee_team_id: nil))
  end

  def self.start!(contact:, body:, channel:, page_context: nil, search_query: nil, email_message_id: nil, client_id: nil)
    transaction do
      thread = create!(contact: contact, channel: channel, page_context: page_context.presence, search_query: search_query.presence,
                       title: body.to_s.squish.truncate(80), waiting_since: Time.current)
      thread.parts.create!(author_type: "contact", author_contact: contact, kind: "comment", body: body,
                           channel: channel, email_message_id: email_message_id, client_id: client_id)
      thread
    end
  end

  # The contact wrote (widget, email link or email). Reopens closed or snoozed threads.
  def contact_comment!(body:, channel:, email_message_id: nil, client_id: nil)
    transaction do
      part = parts.create!(author_type: "contact", author_contact: contact, kind: "comment", body: body, channel: channel,
                           email_message_id: email_message_id, client_id: client_id)
      changes = { waiting_since: waiting_since || Time.current }
      changes.merge!(state: "open", closed_at: nil, snoozed_until: nil) unless state == "open"
      update!(changes)
      part
    end
  end

  # An agent replied to the contact.
  def reply!(user:, body:, client_id: nil)
    transaction do
      part = parts.create!(author_type: "user", author_user: user, kind: "comment", body: body, channel: "admin", client_id: client_id)
      update!(waiting_since: nil, first_response_at: first_response_at || Time.current,
              assignee_user: assignee_user || user)
      part
    end
  end

  def note!(user:, body:, client_id: nil)
    parts.create!(author_type: "user", author_user: user, kind: "note", body: body, channel: "admin", client_id: client_id)
  end

  def assign!(by:, user: nil, team: nil)
    transaction do
      update!(assignee_user: user, assignee_team: team || assignee_team)
      parts.create!(author_type: "user", author_user: by, kind: "assignment", channel: "admin",
                    event: { user_id: user&.id, user: user&.name, team_id: assignee_team_id, team: assignee_team&.name })
      Notification.create!(user: user, thread: self, kind: "assigned") if user && user != by
    end
  end

  def close!(by:)
    transaction do
      update!(state: "closed", closed_at: Time.current, snoozed_until: nil, waiting_since: nil)
      parts.create!(author_type: by ? "user" : "system", author_user: by, kind: "close", channel: by ? "admin" : "system")
    end
  end

  def reopen!(by:)
    transaction do
      update!(state: "open", closed_at: nil, snoozed_until: nil)
      parts.create!(author_type: by ? "user" : "system", author_user: by, kind: "open", channel: by ? "admin" : "system")
    end
  end

  def snooze!(by:, until_time:)
    transaction do
      update!(state: "snoozed", snoozed_until: until_time)
      parts.create!(author_type: "user", author_user: by, kind: "snooze", channel: "admin", event: { until: until_time.iso8601 })
    end
  end

  def last_part_id = parts.maximum(:id).to_i

  def unread_for?(user, read_map)
    (read_map[id] || 0) < (@last_id ||= last_part_id)
  end

  def mark_read!(user)
    ThreadRead.upsert({ thread_id: id, user_id: user.id, last_part_id: last_part_id, read_at: Time.current }, unique_by: %i[thread_id user_id])
  end
end
