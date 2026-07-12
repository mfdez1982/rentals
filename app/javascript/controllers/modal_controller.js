import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["dialog"]

  // Fires once for the dialog present at initial page load, and again any
  // time the <dialog> element itself gets replaced by a Turbo Frame swap
  // (e.g. after a create/edit submission that re-renders the section frame
  // the dialog lives inside — a fresh dialog with no errors means "closed",
  // one with an alert means "reopen and show it"). It does NOT fire just
  // because a *nested* frame inside an otherwise-untouched dialog reloads
  // (e.g. the GET request that loads the edit form into the dialog), so
  // opening the modal that way is never mistaken for a submission result.
  dialogTargetConnected(dialog) {
    if (dialog.querySelector('[role="alert"]')) {
      dialog.showModal()
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
