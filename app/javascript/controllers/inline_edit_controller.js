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
    // Moving focus to a sibling input within the same inline-edit form (e.g.
    // tabbing from start date to end date) isn't a real blur of the form --
    // submitting here would save the sibling field's stale value before the
    // user finishes editing it.
    if (event.relatedTarget && this.inputTargets.includes(event.relatedTarget)) return

    if (!this.isSubmitting) {
      this.isSubmitting = true
      this.formTarget.requestSubmit()
      setTimeout(() => { this.isSubmitting = false }, 100)
    }
  }
}
