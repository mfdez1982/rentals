import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  openEdit(event) {
    const clickedFrame = event.target.closest("turbo-frame")
    this.element.querySelectorAll("turbo-frame[data-editing]").forEach(frame => {
      if (frame !== clickedFrame) {
        frame.removeAttribute("data-editing")
        frame.src = frame.dataset.rowUrl
      }
    })
    if (clickedFrame) clickedFrame.dataset.editing = "true"
  }

  editName(event) {
    const frameId = event.currentTarget.dataset.propertiesFrameId
    const editUrl = event.currentTarget.dataset.propertiesEditUrl
    const frame = document.querySelector(`turbo-frame#${frameId}`)
    if (frame && editUrl) {
      frame.src = editUrl
    }
  }
}
