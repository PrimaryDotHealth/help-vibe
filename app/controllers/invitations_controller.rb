# Accept an invitation: choose a first password from the emailed link.
class InvitationsController < ApplicationController
  allow_unauthenticated_access
  before_action :set_user

  def show; end

  def update
    if @user.update(params.permit(:password, :password_confirmation))
      start_new_session_for @user
      redirect_to(@user.editor? || @user.agent? ? admin_root_path : root_path, notice: "Welcome, #{@user.first_name.presence || @user.email_address}")
    else
      redirect_to invitation_path(params[:token]), alert: "Those passwords didn't match"
    end
  end

  private
    def set_user
      @user = User.find_by_token_for(:invitation, params[:token])
      redirect_to new_session_path, alert: "That invitation link has expired. Ask an admin to resend it." unless @user&.active?
    end
end
