# POST /a/:slug/vote from the help center or the widget (S03, S07).
class Reader::VotesController < Reader::BaseController
  include VisitorTracking
  # In an iframe on another site the session cookie (and so the CSRF token)
  # isn't sent. A forged anonymous vote is harmless, so allow it there.
  # (One `if:`, not `only:` plus `if:`: Rails' skip_* ORs those together.)
  skip_forgery_protection if: -> { params[:source] == "widget" || framed? }

  def create
    @article = Article.find_by!(slug: params[:slug])
    raise ActiveRecord::RecordNotFound unless @article.visible_to?(viewer_for_vote)
    @vote = Vote.record!(article: @article, value: params[:value].to_i == 1 ? 1 : -1, visitor_hash: visitor_hash,
                         source: params[:source] == "widget" ? "widget" : "kb", user: Current.user)
    @vote.update!(comment: params[:comment].to_s.first(1000)) if params[:comment].present?
    render partial: "reader/articles/helpful", locals: { article: @article, vote: @vote, source: @vote.source }
  end

  private
    def viewer_for_vote = params[:source] == "widget" ? Visibility::Viewer.anonymous : viewer
end
