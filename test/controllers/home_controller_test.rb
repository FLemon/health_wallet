require "test_helper"

class HomeControllerTest < ActionDispatch::IntegrationTest
  test "should get index" do
    get root_url
    assert_response :success
  end

  test "displays app name" do
    get root_url
    assert_match "Health Wallet", response.body
  end

  test "displays the fixed navigation links" do
    get root_url

    assert_select "header.site-header"
    assert_select "nav[aria-label='Primary navigation'] a[href='#{patients_path}']", text: "Patients"
    assert_select "nav[aria-label='Primary navigation'] a[href='#{laboratory_imports_path}']", text: "Uploads"
    assert_select "nav[aria-label='Primary navigation'] a[href='#{new_laboratory_import_path}']", text: "New upload"
  end
end
