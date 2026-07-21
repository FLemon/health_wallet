require "test_helper"

class LaboratoryImportsControllerTest < ActionDispatch::IntegrationTest
  test "lists laboratory imports with their submission time and status" do
    pending_import = LaboratoryImport.create!(filename: "pending.txt", file_content: "content")
    completed_import = LaboratoryImport.create!(filename: "completed.txt", file_content: "content", status: "completed")

    get laboratory_imports_url

    assert_response :success
    assert_select "table.imports-table tbody tr", count: 2
    assert_select "a[href='#{laboratory_import_path(pending_import)}']", text: "pending.txt"
    assert_select "a[href='#{laboratory_import_path(completed_import)}']", text: "completed.txt"
    assert_select "time", count: 2
    assert_select ".status-pending", text: "Pending"
    assert_select ".status-completed", text: "Completed"
  end

  test "shows an empty state when there are no laboratory imports" do
    get laboratory_imports_url

    assert_response :success
    assert_select "p", "No laboratory imports have been uploaded yet."
  end

  test "shows the upload form" do
    get new_laboratory_import_url
    assert_response :success
    assert_select "input[type=file]"
  end

  test "creates an import and enqueues processing" do
    file = fixture_file_upload("John_Doe_HL7.txt", "text/plain")

    assert_enqueued_with(job: LaboratoryImportJob) do
      post laboratory_imports_url, params: { laboratory_import: { file: file } }
    end

    assert_redirected_to laboratory_import_url(LaboratoryImport.last)
    assert_equal "pending", LaboratoryImport.last.status
  end

  test "validates an upload before submission" do
    file = fixture_file_upload("John_Doe_HL7.txt", "text/plain")

    post validate_laboratory_imports_url, params: { laboratory_import: { file: file } }

    assert_response :success
    assert_equal "application/json", response.media_type
    assert_equal({ "valid" => true, "filename" => "John_Doe_HL7.txt" }, JSON.parse(response.body))
  end

  test "rejects invalid uploads from the validation endpoint" do
    file = Rack::Test::UploadedFile.new(StringIO.new("John Doe|not-a-date|M|REF-1\n8480-6|120|mmHg\n"), "text/plain", original_filename: "invalid.txt")

    post validate_laboratory_imports_url, params: { laboratory_import: { file: file } }

    assert_response :unprocessable_entity
    payload = JSON.parse(response.body)
    assert_equal false, payload["valid"]
    assert_match "Invalid date", payload["errors"].first
  end

  test "rejects invalid uploads during create without enqueuing a job" do
    file = Rack::Test::UploadedFile.new(StringIO.new("John Doe|not-a-date|M|REF-1\n8480-6|120|mmHg\n"), "text/plain", original_filename: "invalid.txt")

    assert_no_enqueued_jobs do
      post laboratory_imports_url, params: { laboratory_import: { file: file } }
    end

    assert_response :unprocessable_entity
    assert_equal 0, LaboratoryImport.count
    assert_select ".flash-error", /Invalid date/
  end
end
