require "test_helper"

class LaboratoryImportJobTest < ActiveJob::TestCase
  test "marks a valid import as completed" do
    laboratory_import = LaboratoryImport.create!(
      filename: "results.txt",
      file_content: "John Doe|1985-03-15|M|REF-1\n8867-4|72|bpm\n"
    )

    LaboratoryImportJob.perform_now(laboratory_import.id.to_s)

    assert_equal "completed", laboratory_import.reload.status
    assert_equal 1, laboratory_import.patients_created_count
    assert_equal 1, laboratory_import.assessments_created_count
    assert_equal 1, laboratory_import.observations_created_count
    assert_equal 0, laboratory_import.observations_skipped_count
    assert_equal 1, Patient.count
  end

  test "marks an invalid import as failed" do
    laboratory_import = LaboratoryImport.create!(filename: "results.txt", file_content: "invalid")

    LaboratoryImportJob.perform_now(laboratory_import.id.to_s)

    assert_equal "failed", laboratory_import.reload.status
    assert_match "Expected 3 or 4 fields", laboratory_import.error_message
  end

  test "reports observations skipped because an earlier import created them" do
    content = "John Doe|1985-03-15|M|REF-1\n8867-4|72|bpm\n"
    first_import = LaboratoryImport.create!(filename: "first.txt", file_content: content)
    later_import = LaboratoryImport.create!(filename: "later.txt", file_content: content)

    LaboratoryImportJob.perform_now(first_import.id.to_s)
    LaboratoryImportJob.perform_now(later_import.id.to_s)

    assert_equal "completed", later_import.reload.status
    assert_equal 0, later_import.observations_created_count
    assert_equal 1, later_import.observations_skipped_count
  end
end
