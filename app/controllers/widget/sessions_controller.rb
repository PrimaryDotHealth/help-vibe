# POST /widget/session: exchange our app's signed token for a widget cookie.
# The cookie is partitioned (CHIPS), so it works inside the iframe even where
# third-party cookies are blocked. No CSRF token: the signed JWT is the proof,
# and the normal session cookie isn't sent inside a third-party iframe anyway.
class Widget::SessionsController < Widget::BaseController
  skip_forgery_protection

  def create
    identity = WidgetIdentity.from_token(params.require(:token))
    cookies.encrypted[WIDGET_COOKIE] = widget_cookie(identity.to_cookie)
    render json: { kind: identity.kind, name: identity.name }
  rescue WidgetIdentity::Error, ActionController::ParameterMissing => e
    render json: { error: e.message }, status: :unauthorized
  end

  def destroy
    cookies.delete(WIDGET_COOKIE, **widget_cookie_options)
    head :no_content
  end
end
