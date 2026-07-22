class Assessment
  include Mongoid::Document
  include Mongoid::Timestamps

  field :date, type: String
  field :reference, type: String

  belongs_to :patient

  embeds_many :observations
  accepts_nested_attributes_for :observations

  index({ patient_id: 1, reference: 1 }, { unique: true })
end
