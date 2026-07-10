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

  close(event) {
    event.preventDefault()
    this.dialogTarget.close()
  }
}
