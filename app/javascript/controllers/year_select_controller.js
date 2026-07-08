import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { baseUrl: String }

  navigate(event) {
    Turbo.visit(`${this.baseUrlValue}?year=${event.target.value}`)
  }
}
