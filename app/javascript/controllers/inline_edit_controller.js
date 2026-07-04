import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["form", "input"]

  connect() {
    if (this.inputTargets.length > 0) {
      this.inputTargets[0].focus()
    }
    this.isSubmitting = false
  }

  submit(event) {
    if (event.key === "Enter") {
      event.preventDefault()
      if (!this.isSubmitting) {
        this.isSubmitting = true
        this.formTarget.requestSubmit()
        setTimeout(() => { this.isSubmitting = false }, 100)
      }
    }
  }

  blur(event) {
    if (!this.isSubmitting) {
      this.isSubmitting = true
      this.formTarget.requestSubmit()
      setTimeout(() => { this.isSubmitting = false }, 100)
    }
  }
}
