class LaboratoryResultsImporter
  Result = Struct.new(
    :patients_created_count,
    :assessments_created_count,
    :observations_created_count,
    :observations_skipped_count,
    keyword_init: true
  )

  ParseError = LaboratoryResultsValidator::ParseError

  def initialize(content)
    @content = content.to_s.dup.freeze
  end

  def call
    result = Result.new(
      patients_created_count: 0,
      assessments_created_count: 0,
      observations_created_count: 0,
      observations_skipped_count: 0
    )

    LaboratoryResultsValidator.new(@content).call.each do |assessment_data|
      import_assessment(assessment_data, result)
    end

    result
  end

  private

  def import_assessment(data, result)
    patient, patient_created = find_or_create(Patient, patient_attributes(data))
    result.patients_created_count += 1 if patient_created

    assessment, assessment_created = find_or_create(patient.assessments, reference: data[:reference])
    result.assessments_created_count += 1 if assessment_created

    data[:observations].each do |observation_data|
      if assessment.observations.where(code: observation_data[:code]).exists?
        result.observations_skipped_count += 1
        next
      end

      observation = assessment.observations.build(observation_data)
      result.observations_created_count += 1
      observation.save!
    end

    assessment.save!
  end

  def find_or_create(scope, attributes)
    record = scope.where(attributes).first
    return [ record, false ] if record

    [ scope.create!(attributes), true ]
  end

  def patient_attributes(data)
    data.slice(:name, :dob, :sex_at_birth)
  end
end
