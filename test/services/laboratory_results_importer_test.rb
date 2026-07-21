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

  test "imports respiratory rate using its configured LOINC description" do
    LaboratoryResultsImporter.new("John Doe|1985-03-15|M|REF-RESP-001\n9279-1|16|breaths/min\n").call

    observation = assessment_for("John Doe", "REF-RESP-001").observations.first
    assert_equal "9279-1", observation.code
    assert_equal "Respiratory Rate", observation.name
    assert_equal 16.0, observation.value
    assert_equal "breaths/min", observation.units
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

  test "accepts UTF-8 BOM, Windows line endings, blank lines, and surrounding whitespace" do
    content = "\uFEFF  John Doe | 1985-03-15 | M | REF-1 \r\n\r\n 8867-4 | 72 | bpm \r\n"

    LaboratoryResultsImporter.new(content).call

    observation = assessment_for("John Doe", "REF-1").observations.first
    assert_equal 72.0, observation.value
    assert_equal "bpm", observation.units
  end

  [ "NaN", "Infinity", "-Infinity", "not-a-number" ].each do |value|
    test "rejects non-finite or invalid observation value #{value.inspect}" do
      error = assert_raises(LaboratoryResultsImporter::ParseError) do
        LaboratoryResultsImporter.new("John Doe|1985-03-15|M|REF-1\n8867-4|#{value}|bpm\n").call
      end

      assert_match "Invalid observation value", error.message
      assert_equal 0, Patient.count
    end
  end

  test "rejects unsupported codes, incomplete assessments, and observations before headers" do
    [
      "John Doe|1985-03-15|M|REF-1\n9999-9|72|bpm\n",
      "John Doe|1985-03-15|M|REF-1\n",
      "8867-4|72|bpm\n"
    ].each do |content|
      assert_raises(LaboratoryResultsImporter::ParseError) { LaboratoryResultsImporter.new(content).call }
      assert_equal 0, Patient.count
    end
  end

  test "rejects invalid UTF-8 and malformed field counts without creating records" do
    [ "John Doe|1985-03-15|M|REF-1|unexpected\n", "\xFF".b ].each do |content|
      assert_raises(LaboratoryResultsImporter::ParseError) { LaboratoryResultsImporter.new(content).call }
      assert_equal 0, Patient.count
    end
  end

  private

  def import_fixture(filename)
    LaboratoryResultsImporter.new(Rails.root.join("test/fixtures/files", filename).read).call
  end

  def assessment_for(patient_name, reference)
    Patient.where(name: patient_name).first.assessments.where(reference: reference).first
  end
end
