class LaboratoryResultsImporter
  Result = Struct.new(
    :patients_created_count,
    :assessments_created_count,
    :observations_created_count,
    :observations_updated_count,
    keyword_init: true
  )

  ParseError = LaboratoryResultsValidator::ParseError

  def initialize(content)
    @content = content
  end

  def call
    assessments = LaboratoryResultsValidator.new(@content).call
    result = Result.new(
      patients_created_count: 0,
      assessments_created_count: 0,
      observations_created_count: 0,
      observations_updated_count: 0
    )

    assessments.each { |assessment_data| import_assessment(assessment_data, result) }
    result
  end

  private

  def import_assessment(data, result)
    patient = Patient.where(name: data[:name], dob: data[:dob], sex_at_birth: data[:sex_at_birth]).first
    unless patient
      patient = Patient.create!(name: data[:name], dob: data[:dob], sex_at_birth: data[:sex_at_birth])
      result.patients_created_count += 1
    end

    assessment = patient.assessments.where(reference: data[:reference]).first
    unless assessment
      assessment = patient.assessments.create!(reference: data[:reference])
      result.assessments_created_count += 1
    end

    data[:observations].each do |observation_data|
      observation = assessment.observations.where(code: observation_data[:code]).first
      if observation
        result.observations_updated_count += 1
      else
        observation = assessment.observations.build(code: observation_data[:code])
        result.observations_created_count += 1
      end
      observation.assign_attributes(observation_data)
      observation.save!
    end

    assessment.save!
  end
end
