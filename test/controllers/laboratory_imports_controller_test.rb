require "test_helper"

class LaboratoryImportsControllerTest < ActionDispatch::IntegrationTest
  test "shows the upload form" do
    get new_laboratory_import_url
    assert_response :success
    assert_select "input[type=file]"
  end

  test "creates an import and enqueues processing" do
    file = fixture_file_upload("results.txt", "text/plain")

    assert_enqueued_with(job: LaboratoryImportJob) do
      post laboratory_imports_url, params: { laboratory_import: { file: file } }
    end

    assert_redirected_to laboratory_import_url(LaboratoryImport.last)
    assert_equal "pending", LaboratoryImport.last.status
  end
end
