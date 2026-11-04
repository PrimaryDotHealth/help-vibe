# Snoozed conversations come back to the inbox when their time is up.
class UnsnoozeJob < ApplicationJob
  queue_as :default

  def perform
    SupportThread.where(state: "snoozed").where(snoozed_until: ..Time.current).find_each do |thread|
      thread.reopen!(by: nil)
      Notification.create!(user: thread.assignee_user, thread: thread, kind: "replied") if thread.assignee_user
    end
  end
end
