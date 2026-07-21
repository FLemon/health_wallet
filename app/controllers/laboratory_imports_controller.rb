class LaboratoryImportsController < ApplicationController
  def new
    @laboratory_import = LaboratoryImport.new
  end

  def create
    upload = params.dig(:laboratory_import, :file)
    unless upload.present?
      @laboratory_import = LaboratoryImport.new
      @laboratory_import.errors.add(:file, "must be selected")
      return render :new, status: :unprocessable_entity
    end

    @laboratory_import = LaboratoryImport.new(
      filename: upload.original_filename,
      file_content: upload.read
    )
    if @laboratory_import.save
      LaboratoryImportJob.perform_later(@laboratory_import.id.to_s)
      redirect_to @laboratory_import, notice: "File uploaded. Import is pending."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def show
    @laboratory_import = LaboratoryImport.find(params[:id])
  end
end
