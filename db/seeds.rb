# Sample content for local development. Safe to re-run.
# Real content arrives through the Helpjuice importer (M2).

if Rails.env.development?
  admin = User.find_or_initialize_by(email_address: "dev@helpvibe.test")
  admin.update!(password: "password", first_name: "Dev", last_name: "Admin", role: "superadmin")
  puts "Sign in at http://localhost:3000/session/new as dev@helpvibe.test / password"
end
author = User.find_by(role: "superadmin")

chapters = {
  "GET" => [ "Getting started", "Set up your account and learn the basics." ],
  "SCH" => [ "Scheduling", "Appointments, availability and reminders." ],
  "PAT" => [ "Patients and records", "Profiles, documents and history." ],
  "BIL" => [ "Billing and payments", "Invoices, insurance and payouts." ],
  "ACC" => [ "Account and security", "Passwords, two-factor sign-in and team roles." ],
  "INT" => [ "Integrations", "Calendars, labs and other tools." ]
}
chapters.each_with_index do |(code, (name, description)), i|
  Category.find_or_create_by!(code: code) { |c| c.assign_attributes(name: name, description: description, position: i) }
end

articles = [
  [ "SCH", "Reschedule or cancel an appointment", "Move an appointment to a new time, or cancel it and tell the patient why.",
    "reschedule, cancel, move appointment", <<~HTML ],
    <h2>Reschedule an appointment</h2>
    <ol><li>Open <strong>Calendar</strong> and select the appointment.</li><li>Choose <strong>Reschedule</strong>.</li>
    <li>Pick a new date and time. Times are shown in your time zone.</li><li>Decide whether to notify the patient, then choose <strong>Save</strong>.</li></ol>
    <h2>Cancel an appointment</h2>
    <p>Cancelling frees the slot straight away. The patient gets an email with the reason you enter.</p>
    <blockquote>Caution: Cancelling within 24 hours of the start may apply your late-cancellation fee.</blockquote>
    <blockquote>Tip: Patients can reschedule themselves from the link in their confirmation email, if you allow it.</blockquote>
    <h2>Common questions</h2>
    <h3>Can I undo a cancellation?</h3><p>No. Book a new appointment in the same slot instead.</p>
    <h3>What does the patient see?</h3><p>An email, and a text if reminders are on, with the new time or your reason.</p>
  HTML
  [ "SCH", "Set your weekly availability", "Choose the hours patients can book.", "availability, hours, schedule", <<~HTML ],
    <h2>Set your hours</h2><ol><li>Open <strong>Settings → Availability</strong>.</li><li>Add a time range for each day you work.</li><li>Choose <strong>Save</strong>.</li></ol>
    <h2>Time off</h2><p>Add a date range under <strong>Time off</strong> to block bookings while you're away.</p>
  HTML
  [ "BIL", "Send an invoice to a patient", "Email or text an invoice the patient can pay straight away.", "invoice, bill, payment link", <<~HTML ],
    <h2>Send it</h2><ol><li>Open the invoice and check the line items.</li><li>Choose <strong>Send</strong>, then pick email or text.</li><li>The patient can pay from the link straight away.</li></ol>
  HTML
  [ "BIL", "Refund a payment", "Issue a full or partial refund from the invoice.", "refund, chargeback", <<~HTML ],
    <h2>Refund</h2><ol><li>Open the invoice.</li><li>Choose <strong>Refund</strong>.</li><li>Pick full or partial, then confirm.</li></ol>
    <p>Card refunds take 5 to 10 business days to reach the patient.</p>
  HTML
  [ "ACC", "Reset your password", "Get back into your account.", "password, locked out, login", <<~HTML ],
    <h2>Reset it</h2><ol><li>On the sign-in page, choose <strong>Forgot your password?</strong></li><li>Enter your email and open the link we send.</li></ol>
  HTML
  [ "GET", "Invite a teammate and choose their role", "Add people to your practice.", "invite, team, roles", <<~HTML ]
    <h2>Invite</h2><ol><li>Open <strong>Settings → Team</strong>.</li><li>Choose <strong>Invite</strong> and enter their email.</li><li>Pick a role, then send.</li></ol>
  HTML
]

articles.each do |code, title, subtitle, keywords, body|
  next if ArticleVersion.exists?(title: title)
  article = Article.start!(title: title, category: Category.find_by!(code: code), author: author)
  article.update!(keyword_list: keywords)
  version = article.versions.first
  version.update!(subtitle: subtitle)
  version.save_revision!(body: body, author: author, base_revision_id: nil)
  version.publish!(by: author)
end

puts "#{Category.count} chapters, #{Article.count} articles"
