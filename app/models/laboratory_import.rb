class LaboratoryImport
  include Mongoid::Document
  include Mongoid::Timestamps

  STATUSES = %w[pending processing completed failed].freeze

  field :filename, type: String
  field :file_content, type: String
  field :status, type: String, default: "pending"
  field :error_message, type: String
  field :completed_at, type: Time
  field :patients_created_count, type: Integer, default: 0
  field :assessments_created_count, type: Integer, default: 0
  field :observations_created_count, type: Integer, default: 0
  field :observations_updated_count, type: Integer, default: 0

  validates :filename, :file_content, presence: true
  validates :status, inclusion: { in: STATUSES }
end
