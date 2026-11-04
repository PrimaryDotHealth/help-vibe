class UsersMailer < ApplicationMailer
  def invitation(user)
    @user = user
    @url = invitation_url(user.generate_token_for(:invitation))
    mail subject: "You've been invited to the help center admin", to: user.email_address
  end
end
