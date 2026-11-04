# Page suggestions: which articles the widget leads with on which page of our app.
class Admin::ContextRulesController < Admin::BaseController
  before_action :require_publisher, except: :index
  before_action :set_rule, only: %i[edit update destroy]

  def index
    @rules = ContextRule.includes(articles: :versions).order(priority: :desc, id: :asc)
    @pages = SearchEvent.where(source: "widget").where.not(page_context: nil).where(created_at: 30.days.ago..)
                        .group(:page_context).order(Arel.sql("count(*) desc")).limit(8).count
  end

  def new = @rule = ContextRule.new(url_pattern: params[:pattern])

  def create
    @rule = ContextRule.new(rule_params)
    @rule.save ? redirect_to(admin_context_rules_path, notice: "Saved") : render(:new, status: :unprocessable_entity)
  end

  def edit; end

  def update
    @rule.assign_attributes(rule_params)
    @rule.save ? redirect_to(admin_context_rules_path, notice: "Saved") : render(:edit, status: :unprocessable_entity)
  end

  def destroy
    @rule.destroy!
    redirect_to admin_context_rules_path, notice: "Removed"
  end

  private
    def set_rule = @rule = ContextRule.find(params[:id])
    def rule_params = params.require(:context_rule).permit(:name, :url_pattern, :priority, :article_codes)
end
