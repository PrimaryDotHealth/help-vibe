# S29: the shared inbox. Oldest-waiting first.
class Admin::InboxController < Admin::SupportBaseController
  def show
    @teams = Current.user.admin? ? Team.order(:name) : Current.user.teams.order(:name)
    @view = params[:view].presence || "mine"
    base = visible_threads
    @counts = {
      "mine" => base.open_state.where(assignee_user: Current.user).count,
      "unassigned" => base.open_state.where(assignee_user_id: nil).count,
      "all" => base.open_state.count,
      "snoozed" => base.where(state: "snoozed").count
    }
    @team_counts = base.open_state.where(assignee_team_id: @teams.map(&:id)).group(:assignee_team_id).count
    @threads = scope_for(base).includes(:contact, :assignee_user, :assignee_team, :ticket_type).waiting_first.limit(100).to_a
    @reads = ThreadRead.where(user: Current.user, thread_id: @threads.map(&:id)).pluck(:thread_id, :last_part_id).to_h
    @last_parts = ThreadPart.where(thread_id: @threads.map(&:id)).group(:thread_id).maximum(:id)
    @previews = ThreadPart.where(id: ThreadPart.where(thread_id: @threads.map(&:id), kind: "comment").group(:thread_id).select("max(id)")).index_by(&:thread_id)
  end

  private
    def scope_for(base)
      case @view
      when "mine" then base.open_state.where(assignee_user: Current.user)
      when "unassigned" then base.open_state.where(assignee_user_id: nil)
      when "snoozed" then base.where(state: "snoozed")
      when "closed" then base.where(state: "closed").reorder(closed_at: :desc)
      when /\Ateam-(\d+)\z/ then base.open_state.where(assignee_team_id: Regexp.last_match(1).to_i)
      else base.open_state
      end
    end
end
