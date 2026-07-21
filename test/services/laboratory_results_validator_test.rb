require "test_helper"

class LaboratoryResultsValidatorTest < ActiveSupport::TestCase
  test "validates the John Doe example file without touching the database" do
    content = Rails.root.join("test/fixtures/files/John_Doe_HL7.txt").read

    parsed_assessments = LaboratoryResultsValidator.new(content).call

    assert_equal 1, parsed_assessments.size
    assert_equal "John Doe", parsed_assessments.first[:name]
    assert_equal "REF-2024-001", parsed_assessments.first[:reference]
    assert_equal 4, parsed_assessments.first[:observations].size
    assert_equal 0, Patient.count
  end

  test "rejects malformed input before any persistence can happen" do
    error = assert_raises(LaboratoryResultsValidator::ParseError) do
      LaboratoryResultsValidator.new("John Doe|not-a-date|M|REF-1\n8480-6|120|mmHg\n").call
    end

    assert_match "Invalid date", error.message
    assert_equal 0, Patient.count
  end

  test "accepts duplicate observations for the importer to skip" do
    content = <<~RESULTS
      John Doe|1985-03-15|M|REF-1
      8867-4|72|bpm
      8867-4|75|bpm
    RESULTS

    parsed_assessments = LaboratoryResultsValidator.new(content).call

    assert_equal 2, parsed_assessments.first[:observations].size
    assert_equal 0, Patient.count
  end

  test "uses an immutable copy of the supplied content" do
    content = String.new("John Doe|1985-03-15|M|REF-1\n8867-4|72|bpm\n")
    validator = LaboratoryResultsValidator.new(content)
    content.replace(String.new("invalid"))

    parsed_assessments = validator.call

    assert_equal "John Doe", parsed_assessments.first[:name]
  end
end
