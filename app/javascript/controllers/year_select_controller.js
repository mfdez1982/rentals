import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["year"]
  static values = { baseUrl: String }

  reload() {
    const url = `${this.baseUrlValue}?year=${this.yearTarget.value}`
    const frame = this.element.closest("turbo-frame")
    if (frame) {
      frame.src = url
    } else {
      Turbo.visit(url)
    }
  }
}
