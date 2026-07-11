import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { baseUrl: String }

  navigate(event) {
    const url = `${this.baseUrlValue}?year=${event.target.value}`
    const frame = this.element.closest("turbo-frame")
    if (frame) {
      frame.src = url
    } else {
      Turbo.visit(url)
    }
  }
}
