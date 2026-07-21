require "test_helper"

class LaboratoryResultsImporterTest < ActiveSupport::TestCase
  test "imports multiple assessments and gives known observations their names" do
    content = <<~HL7
      John Doe|1985-03-15|M|REF-2024-001
      8480-6|120|mmHg
      8462-4|80|mmHg
      Jane Smith|1990-07-22|F|REF-2024-002
      2708-6|98|%
    HL7

    LaboratoryResultsImporter.new(content).call

    john = Patient.where(name: "John Doe", dob: Date.new(1985, 3, 15), sex_at_birth: "M").first
    assert_equal 2, john.assessments.first.observations.count
    assert_equal "Blood Pressure (Systolic)", john.assessments.first.observations.where(code: "8480-6").first.name
    assert_equal 1, Patient.where(name: "Jane Smith").count
  end

  test "updates records when the same file is imported again" do
    patient = Patient.create!(name: "John Doe", dob: Date.new(1985, 3, 15), sex_at_birth: "M")
    assessment = patient.assessments.create!(reference: "REF-2024-001")
    assessment.observations.create!(name: "Blood Pressure (Systolic)", code: "8480-6", value: 100, units: "mmHg")

    LaboratoryResultsImporter.new("John Doe|1985-03-15|M|REF-2024-001\n8480-6|120|kPa\n").call

    assert_equal 1, Patient.count
    assert_equal 1, patient.assessments.count
    observation = Assessment.find(assessment.id).observations.first
    assert_equal 120.0, observation.value
    assert_equal "kPa", observation.units
  end

  test "rejects malformed input before records are created" do
    error = assert_raises(LaboratoryResultsImporter::ParseError) do
      LaboratoryResultsImporter.new("John Doe|not-a-date|M|REF-1\n8480-6|120|mmHg\n").call
    end

    assert_match "Invalid date", error.message
    assert_equal 0, Patient.count
  end

end
