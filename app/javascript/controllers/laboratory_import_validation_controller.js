import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [ "file", "message", "submit" ]
  static values = { url: String }

  connect() {
    this.disableSubmit()
  }

  async validate() {
    const file = this.fileTarget.files[0]
    this.disableSubmit()

    if (!file) {
      this.updateMessage("Choose a file to validate it before upload.", false)
      return
    }

    this.updateMessage("Validating file...", false)

    const formData = new FormData()
    formData.append("laboratory_import[file]", file)

    try {
      const response = await fetch(this.urlValue, {
        method: "POST",
        headers: {
          "X-CSRF-Token": this.csrfToken,
          "Accept": "application/json"
        },
        body: formData
      })
      const payload = await response.json()

      if (response.ok && payload.valid) {
        this.updateMessage("Validation passed. You can upload the file.", true)
        this.submitTarget.disabled = false
        return
      }

      this.updateMessage((payload.errors || [ "Validation failed." ]).join(" "), false)
    } catch (_error) {
      this.updateMessage("Validation request could not be completed.", false)
    }
  }

  disableSubmit() {
    this.submitTarget.disabled = true
  }

  updateMessage(message, valid) {
    this.messageTarget.textContent = message
    this.messageTarget.classList.toggle("is-valid", valid)
    this.messageTarget.classList.toggle("is-invalid", !valid)
  }

  get csrfToken() {
    return document.querySelector('meta[name="csrf-token"]')?.content || ""
  }
}
