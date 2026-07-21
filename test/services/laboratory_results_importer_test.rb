require "test_helper"

class LaboratoryResultsImporterTest < ActiveSupport::TestCase
  test "imports the John Doe example file" do
    import_fixture("John_Doe_HL7.txt")

    assessment = assessment_for("John Doe", "REF-2024-001")
    assert_equal 4, assessment.observations.count
    assert_equal "Blood Pressure (Systolic)", assessment.observations.where(code: "8480-6").first.name
    assert_equal 98.6, assessment.observations.where(code: "8310-5").first.value
  end

  test "imports the Jane Smith example file" do
    import_fixture("Jane_Smith_HL7.txt")

    assessment = assessment_for("Jane Smith", "REF-2024-002")
    assert_equal 4, assessment.observations.count
    assert_equal 65.5, assessment.observations.where(code: "29463-7").first.value
    assert_equal "mg/dL", assessment.observations.where(code: "2339-0").first.units
  end

  test "imports the multiple patients example file" do
    import_fixture("Multiple_Patients_HL7.txt")

    assert_equal 3, Patient.count
    assert_equal 1, assessment_for("John Doe", "REF-2024-003").observations.count
    assert_equal 2, assessment_for("Jane Smith", "REF-2024-004").observations.count
    assert_equal 2, assessment_for("Josh Brown", "REF-2024-005").observations.count
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

  private

  def import_fixture(filename)
    LaboratoryResultsImporter.new(Rails.root.join("test/fixtures/files", filename).read).call
  end

  def assessment_for(patient_name, reference)
    Patient.where(name: patient_name).first.assessments.where(reference: reference).first
  end
end
