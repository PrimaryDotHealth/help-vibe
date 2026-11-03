namespace :helpvibe do
  desc "Create or update a staff user: bin/rails 'helpvibe:user[you@company.com,superadmin]' (PASSWORD=... optional)"
  task :user, %i[email role] => :environment do |_, args|
    email = args[:email] or abort "usage: bin/rails 'helpvibe:user[email,role]'"
    role = args[:role].presence || "superadmin"
    abort "role must be one of #{User::ROLES.join(", ")}" unless User::ROLES.include?(role)
    password = ENV["PASSWORD"].presence || SecureRandom.base58(16)
    user = User.find_or_initialize_by(email_address: email.strip.downcase)
    user.update!(role: role, password: password, active: true, first_name: user.first_name.presence || email.split("@").first.capitalize)
    puts "#{user.email_address} is a #{role}."
    puts "Password: #{password}" unless ENV["PASSWORD"]
  end
end
