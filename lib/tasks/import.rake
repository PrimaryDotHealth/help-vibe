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

    desc "Import a Helpjuice HTML export from S3 or a local folder. helpvibe:import:helpjuice_html[s3://bucket/folder/] " \
         "(a folder, or one .html file with METADATA=s3://bucket/metadata.json). Options: IMAGES=0"
    task :helpjuice_html, [ :location ] => :environment do |_, args|
      location = args[:location].presence or abort "Pass a location: bin/rails 'helpvibe:import:helpjuice_html[s3://bucket/folder/]'"
      author = User.find_by(role: "superadmin") or abort "Create a superadmin first: bin/rails 'helpvibe:user[you@company.com]'"
      importer = Helpvibe::Importers::HelpjuiceHtml.new(location: location, metadata: ENV["METADATA"].presence, author: author,
                                                        images: ENV["IMAGES"] != "0", log: ->(m) { puts m })
      begin
        importer.call
      ensure
        run = importer.run
        puts "\n#{run.status.capitalize}: #{run.stats.except("warnings").map { "#{_1} #{_2}" }.join(", ")}"
        puts "  #{run.error}" if run.error
        Array(run.stats["warnings"]).each { puts "  ! #{_1}" }
      end
    end
  end
end
