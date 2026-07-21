require "test_helper"

class LaboratoryImportsControllerTest < ActionDispatch::IntegrationTest
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
