class ImportHelpjuiceHtmlJob < ApplicationJob
  queue_as :default

  def perform(run_id, location, metadata: nil, images: true)
    run = ImportRun.find(run_id)
    Helpvibe::Importers::HelpjuiceHtml.new(location: location, metadata: metadata, author: run.started_by, run: run, images: images).call
  end
end
