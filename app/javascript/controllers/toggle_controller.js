import { Controller } from "@hotwired/stimulus"

// Generic show/hide toggle: a checkbox drives the visibility of a target
// wrapper element. Used to reveal the collectable-expense period fields
// only when the "collectable" checkbox is checked.
export default class extends Controller {
  static targets = ["checkbox", "wrapper"]

  connect() {
    this.update()
  }

  update() {
    this.wrapperTargets.forEach((wrapper) => {
      wrapper.classList.toggle("hidden", !this.checkboxTarget.checked)
    })
  }
}
