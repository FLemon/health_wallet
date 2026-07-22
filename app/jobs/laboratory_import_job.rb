class LaboratoryImportJob < ApplicationJob
  queue_as :default

  def perform(import_id)
    laboratory_import = LaboratoryImport.find(import_id)
    laboratory_import.update!(status: "processing", error_message: nil)

    result = LaboratoryResultsImporter.new(laboratory_import.file_content).call
    laboratory_import.update!(
      status: "completed",
      completed_at: Time.current,
      patients_created_count: result.patients_created_count,
      assessments_created_count: result.assessments_created_count,
      observations_created_count: result.observations_created_count,
      observations_skipped_count: result.observations_skipped_count
    )
  rescue Mongoid::Errors::DocumentNotFound
    # The import was removed before the job started.
  rescue StandardError => error
    laboratory_import&.update(status: "failed", error_message: error.message, completed_at: Time.current)
    Rails.logger.error("Laboratory import #{import_id} failed: #{error.full_message}")
  end
end
