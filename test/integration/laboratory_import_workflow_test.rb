require "test_helper"

class LaboratoryImportWorkflowTest < ActionDispatch::IntegrationTest
  test "uploads, processes, and displays a completed import in history" do
    post laboratory_imports_url, params: { laboratory_import: { file: fixture_file_upload("John_Doe_HL7.txt", "text/plain") } }

    laboratory_import = LaboratoryImport.last
    assert_redirected_to laboratory_import_url(laboratory_import)

    LaboratoryImportJob.perform_now(laboratory_import.id.to_s)

    get laboratory_imports_url
    assert_select "a[href='#{laboratory_import_path(laboratory_import)}']", text: "John_Doe_HL7.txt"
    assert_select ".status-completed", text: "Completed"

    get laboratory_import_url(laboratory_import)
    assert_select "dt", text: "Patients created"
    assert_select "dd", text: "1"
    assert_select "dt", text: "Observations created"
    assert_select "dd", text: "4"
  end

  test "rejects an invalid file during preflight and upload without creating an import" do
    invalid_content = "John Doe|not-a-date|M|REF-1\n8480-6|120|mmHg\n"

    post validate_laboratory_imports_url, params: { laboratory_import: { file: uploaded_file(invalid_content) } }
    assert_response :unprocessable_entity
    assert_equal 0, LaboratoryImport.count

    post laboratory_imports_url, params: { laboratory_import: { file: uploaded_file(invalid_content) } }
    assert_response :unprocessable_entity
    assert_equal 0, LaboratoryImport.count
  end

  test "reports duplicate observations skipped by a later import" do
    content = "Integration Duplicate|1985-03-15|Female|INTEGRATION-SKIP-001\n8867-4|72|bpm\n"

    post laboratory_imports_url, params: { laboratory_import: { file: uploaded_file(content, "first.txt") } }
    LaboratoryImportJob.perform_now(LaboratoryImport.last.id.to_s)

    post laboratory_imports_url, params: { laboratory_import: { file: uploaded_file(content, "later.txt") } }
    later_import = LaboratoryImport.last
    LaboratoryImportJob.perform_now(later_import.id.to_s)

    get laboratory_import_url(later_import)
    assert_select ".status-completed", text: "Completed"
    assert_select "dt", text: "Duplicate observations skipped"
    assert_select "dd", text: "1"
  end

  test "navigates between patients, a new upload, and import history" do
    get patients_url
    assert_select "a[href='#{new_laboratory_import_path}']", text: "New upload"

    get new_laboratory_import_url
    assert_select "a[href='#{laboratory_imports_path}']", text: "Uploads"

    get laboratory_imports_url
    assert_select "a[href='#{patients_path}']", text: "Patients"
  end

  private

  def uploaded_file(content, filename = "results.txt")
    Rack::Test::UploadedFile.new(StringIO.new(content), "text/plain", original_filename: filename)
  end
end
