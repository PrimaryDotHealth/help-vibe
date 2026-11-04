class ReviewMailer < ApplicationMailer
  def requested(review, reviewer)
    @review, @article = review, review.version.article
    @url = edit_admin_article_url(@article)
    mail to: reviewer.email_address, subject: "Review requested: #{@article.code} #{review.version.title}"
  end

  def decided(review, reviewer, decision, message)
    @review, @article, @reviewer, @decision, @message = review, review.version.article, reviewer, decision, message
    @url = edit_admin_article_url(@article)
    mail to: review.requested_by.email_address,
         subject: "#{decision == "approved" ? "Approved" : "Changes requested"}: #{@article.code} #{review.version.title}"
  end
end
