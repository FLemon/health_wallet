require "test_helper"
require "rake"

class ImportIndexesTest < ActiveSupport::TestCase
  setup do
    Rails.application.load_tasks unless Rake::Task.task_defined?("db:mongoid:create_indexes")
    Rake::Task["db:mongoid:create_indexes"].reenable
    Rake::Task["db:mongoid:create_indexes"].invoke
  end

  test "patients have a physical unique identity index" do
    index = unique_index_for(Patient, "name" => 1, "dob" => 1, "sex_at_birth" => 1)

    assert_equal true, index["unique"]
  end

  test "assessments have a physical unique reference index within a patient" do
    index = unique_index_for(Assessment, "patient_id" => 1, "reference" => 1)

    assert_equal true, index["unique"]
  end

  private

  def unique_index_for(model, key)
    model.collection.indexes.to_a.find { |index| index["key"] == key }
  end
end
