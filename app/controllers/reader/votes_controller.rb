# POST /a/:slug/vote from the help center or the widget (S03, S07).
class Reader::VotesController < Reader::BaseController
  include VisitorTracking
  skip_forgery_protection only: :create, if: -> { params[:source] == "widget" }   # iframe: no first-party session cookie

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
