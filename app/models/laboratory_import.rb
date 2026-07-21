class LaboratoryImport
  include Mongoid::Document
  include Mongoid::Timestamps

  STATUSES = %w[pending processing completed failed].freeze

  field :filename, type: String
  field :file_content, type: String
  field :status, type: String, default: "pending"
  field :error_message, type: String
  field :completed_at, type: Time

  validates :filename, :file_content, presence: true
  validates :status, inclusion: { in: STATUSES }
end
