# One message, internal note or event in a support thread. Customers only
# ever see comments (and a few events); notes are internal.
class ThreadPart < ApplicationRecord
  CONTACT_VISIBLE = %w[comment rating article close open ticket_state_change].freeze

  belongs_to :thread, class_name: "SupportThread", inverse_of: :parts, touch: true
  belongs_to :author_user, class_name: "User", optional: true
  belongs_to :author_contact, class_name: "Contact", optional: true

  has_many_attached :files

  validates :body, presence: true, if: -> { kind.in?(%w[comment note]) && !files.attached? }
  validates :body, length: { maximum: 20_000 }

  after_create_commit :broadcast_to_viewers
  after_create_commit :notify, if: -> { kind == "comment" }

  def contact_visible? = CONTACT_VISIBLE.include?(kind)
  def message? = kind.in?(%w[comment note])
  def from_contact? = author_type == "contact"
  def author_name = from_contact? ? author_contact&.display_name : (author_user&.name || "helpvibe")

  private
    def broadcast_to_viewers
      broadcast_append_later_to [ thread, :agents ], target: "thread_parts", partial: "admin/support_threads/part", locals: { part: self }
      if contact_visible?
        broadcast_append_later_to [ thread, :contact ], target: "thread_parts", partial: "widget/conversations/part", locals: { part: self }
      end
    end

    def notify
      if from_contact?
        recipients = thread.assignee_user ? [ thread.assignee_user ] : User.active.joins(:team_members).where(team_members: { team_id: thread.assignee_team_id }).distinct.to_a
        recipients.each do |user|
          Notification.create!(user: user, thread: thread, kind: "replied")
          ThreadMailer.contact_replied(self, user).deliver_later
        end
      elsif thread.contact&.email.present?
        ThreadMailer.agent_replied(self).deliver_later
      end
    end
end
