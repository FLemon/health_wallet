class LaboratoryImportsController < ApplicationController
  def new
    @laboratory_import = LaboratoryImport.new
  end

  def validate
    content, filename = uploaded_content_and_filename!
    LaboratoryResultsValidator.new(content).call

    render json: { valid: true, filename: filename }
  rescue LaboratoryResultsValidator::ParseError => error
    render json: { valid: false, errors: [ error.message ] }, status: :unprocessable_entity
  end

  def create
    content, filename = uploaded_content_and_filename!
    LaboratoryResultsValidator.new(content).call

    @laboratory_import = LaboratoryImport.new(
      filename: filename,
      file_content: content
    )
    if @laboratory_import.save
      LaboratoryImportJob.perform_later(@laboratory_import.id.to_s)
      redirect_to @laboratory_import, notice: "File uploaded. Import is pending."
    else
      render :new, status: :unprocessable_entity
    end
  rescue LaboratoryResultsValidator::ParseError => error
    @laboratory_import = LaboratoryImport.new
    @laboratory_import.errors.add(:file, error.message)
    render :new, status: :unprocessable_entity
  end

  def show
    @laboratory_import = LaboratoryImport.find(params[:id])
  end

  private

  def uploaded_content_and_filename!
    upload = params.dig(:laboratory_import, :file)
    raise LaboratoryResultsValidator::ParseError, "must be selected" unless upload.present?

    content = upload.read.force_encoding(Encoding::UTF_8)
    raise LaboratoryResultsValidator::ParseError, "must be valid UTF-8 text" unless content.valid_encoding?

    [ content, upload.original_filename ]
  end
end
