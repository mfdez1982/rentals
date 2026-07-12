import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["dialog"]

  connect() {
    if (this.dialogTarget.querySelector('[role="alert"]')) {
      this.dialogTarget.showModal()
    }
  }

  open(event) {
    event.preventDefault()
    this.dialogTarget.showModal()
  }

  // Used on links that also need to navigate a Turbo Frame (e.g. loading
  // an edit form into the dialog) — must not preventDefault or Turbo won't
  // intercept the click to perform the frame navigation.
  openFrame(event) {
    this.dialogTarget.showModal()
  }

  close(event) {
    event.preventDefault()
    this.dialogTarget.close()
  }
}
