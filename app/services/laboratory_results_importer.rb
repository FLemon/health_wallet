require "date"

class LaboratoryResultsImporter
  OBSERVATION_NAMES = {
    "8480-6" => "Blood Pressure (Systolic)",
    "8462-4" => "Blood Pressure (Diastolic)",
    "8867-4" => "Heart Rate",
    "8310-5" => "Body Temperature",
    "9279-1" => "Respiratory Rate",
    "2708-6" => "Oxygen Saturation",
    "29463-7" => "Body Weight",
    "8302-2" => "Body Height",
    "2339-0" => "Blood Glucose",
    "2093-3" => "Cholesterol"
  }.freeze

  class ParseError < StandardError; end

  def initialize(content)
    @content = content
  end

  def call
    parse.each { |assessment_data| import_assessment(assessment_data) }
  end

  private

  def parse
    assessments = []
    current_assessment = nil
    content = normalized_content

    content.each_line.with_index(1) do |line, line_number|
      line = line.strip
      next if line.empty?

      values = line.split("|", -1).map(&:strip)
      case values.length
      when 4
        ensure_assessment_has_observations!(current_assessment)
        current_assessment = parse_header(values, line_number)
        assessments << current_assessment
      when 3
        raise ParseError, "Observation before an assessment on line #{line_number}" unless current_assessment

        current_assessment[:observations] << parse_observation(values, line_number)
      else
        raise ParseError, "Expected 3 or 4 fields on line #{line_number}"
      end
    end

    raise ParseError, "The file does not contain an assessment" if assessments.empty?
    ensure_assessment_has_observations!(current_assessment)

    assessments
  end

  def normalized_content
    content = @content.to_s.dup.force_encoding(Encoding::UTF_8)
    raise ParseError, "The file is not valid UTF-8 text" unless content.valid_encoding?

    content.delete_prefix!("\uFEFF")
    content
  end

  def parse_header(values, line_number)
    name, dob, sex_at_birth, reference = values
    raise ParseError, "Missing patient or assessment information on line #{line_number}" if values.any?(&:blank?)

    {
      name: name,
      dob: Date.iso8601(dob),
      sex_at_birth: sex_at_birth,
      reference: reference,
      observations: [],
      line_number: line_number
    }
  rescue Date::Error
    raise ParseError, "Invalid date of birth on line #{line_number}"
  end

  def parse_observation(values, line_number)
    code, value, units = values
    raise ParseError, "Missing observation information on line #{line_number}" if values.any?(&:blank?)
    raise ParseError, "Unknown observation code #{code} on line #{line_number}" unless OBSERVATION_NAMES.key?(code)

    numeric_value = Float(value)
    raise ParseError, "Invalid observation value on line #{line_number}" unless numeric_value.finite?

    { code: code, value: numeric_value, units: units, name: OBSERVATION_NAMES.fetch(code) }
  rescue ArgumentError
    raise ParseError, "Invalid observation value on line #{line_number}"
  end

  def ensure_assessment_has_observations!(assessment)
    return unless assessment && assessment[:observations].empty?

    raise ParseError, "Assessment declared on line #{assessment[:line_number]} has no observations"
  end

  def import_assessment(data)
    patient = Patient.where(name: data[:name], dob: data[:dob], sex_at_birth: data[:sex_at_birth]).first ||
      Patient.create!(name: data[:name], dob: data[:dob], sex_at_birth: data[:sex_at_birth])
    assessment = patient.assessments.where(reference: data[:reference]).first ||
      patient.assessments.create!(reference: data[:reference])

    data[:observations].each do |observation_data|
      observation = assessment.observations.where(code: observation_data[:code]).first || assessment.observations.build(code: observation_data[:code])
      observation.assign_attributes(observation_data)
      observation.save!
    end

    assessment.save!
  end
end
