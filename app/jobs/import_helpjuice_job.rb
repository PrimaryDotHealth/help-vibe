class ImportHelpjuiceJob < ApplicationJob
  queue_as :default

  def perform(run_id, users: false, images: true)
    run = ImportRun.find(run_id)
    client = Helpvibe::Importers::Helpjuice::Client.new(subdomain: ENV.fetch("HELPJUICE_SUBDOMAIN"), api_key: ENV.fetch("HELPJUICE_API_KEY"))
    Helpvibe::Importers::Helpjuice.new(client: client, author: run.started_by, run: run, users: users, images: images).call
  end
end
