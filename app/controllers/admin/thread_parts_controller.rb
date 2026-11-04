# Agent replies and internal notes.
class Admin::ThreadPartsController < Admin::SupportBaseController
  def create
    thread = visible_threads.find_by!(number: params[:support_thread_number])
    body = params[:body].to_s.strip
    part = params[:note].present? ? thread.note!(user: Current.user, body: body, client_id: params[:client_id].presence)
                                  : thread.reply!(user: Current.user, body: body, client_id: params[:client_id].presence)
    Array(params[:files]).compact_blank.first(10).each { part.files.attach(_1) }
    Macro.where(id: params[:macro_id]).update_all("uses = uses + 1") if params[:macro_id].present?
    thread.close!(by: Current.user) if params[:and_close].present? && params[:note].blank?
    respond_to do |format|
      format.turbo_stream { head :no_content }   # the part arrives by broadcast
      format.html { redirect_to admin_support_thread_path(thread) }
    end
  rescue ActiveRecord::RecordInvalid => e
    redirect_to admin_support_thread_path(thread), alert: e.record.errors.full_messages.to_sentence
  rescue ActiveRecord::RecordNotUnique
    redirect_to admin_support_thread_path(thread)
  end
end
