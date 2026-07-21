require "test_helper"

class LaboratoryImportJobTest < ActiveJob::TestCase
  test "marks a valid import as completed" do
    laboratory_import = LaboratoryImport.create!(
      filename: "results.txt",
      file_content: "John Doe|1985-03-15|M|REF-1\n8867-4|72|bpm\n"
    )

    LaboratoryImportJob.perform_now(laboratory_import.id.to_s)

    assert_equal "completed", laboratory_import.reload.status
    assert_equal 1, Patient.count
  end

  test "marks an invalid import as failed" do
    laboratory_import = LaboratoryImport.create!(filename: "results.txt", file_content: "invalid")

    LaboratoryImportJob.perform_now(laboratory_import.id.to_s)

    assert_equal "failed", laboratory_import.reload.status
    assert_match "Expected 3 or 4 fields", laboratory_import.error_message
  end
end
