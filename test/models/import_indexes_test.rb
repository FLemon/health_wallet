require "test_helper"

class ImportIndexesTest < ActiveSupport::TestCase
  test "patients have a unique identity index" do
    index = Patient.index_specifications.find { |specification| specification.options[:unique] }

    assert_equal({ name: 1, dob: 1, sex_at_birth: 1 }, index.key)
  end

  test "assessments have a unique reference within a patient" do
    index = Assessment.index_specifications.find { |specification| specification.options[:unique] }

    assert_equal({ patient_id: 1, reference: 1 }, index.key)
  end
end
