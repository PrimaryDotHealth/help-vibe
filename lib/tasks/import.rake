namespace :helpvibe do
  namespace :import do
    desc "Import from Helpjuice. Needs HELPJUICE_SUBDOMAIN and HELPJUICE_API_KEY. Options: USERS=1 IMAGES=0"
    task helpjuice: :environment do
      subdomain = ENV["HELPJUICE_SUBDOMAIN"].presence or abort "Set HELPJUICE_SUBDOMAIN (the part before .helpjuice.com)"
      key = ENV["HELPJUICE_API_KEY"].presence or abort "Set HELPJUICE_API_KEY (Helpjuice → Settings → API credentials)"
      author = User.find_by(role: "superadmin") or abort "Create a superadmin first: bin/rails 'helpvibe:user[you@company.com]'"
      client = Helpvibe::Importers::Helpjuice::Client.new(subdomain: subdomain, api_key: key)
      importer = Helpvibe::Importers::Helpjuice.new(client: client, author: author, users: ENV["USERS"] == "1",
                                                     images: ENV["IMAGES"] != "0", log: ->(m) { puts m })
      importer.call
      run = importer.run
      puts "\nDone: #{run.stats.except("warnings").map { "#{_1} #{_2}" }.join(", ")}"
      Array(run.stats["warnings"]).each { puts "  ! #{_1}" }
    end
  end
end
