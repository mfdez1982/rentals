import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { activeTab: String }

  connect() {
    this.element.querySelectorAll("nav a[data-tabs-tab]").forEach(tab => tab.classList.add("tab-link"))
    this.showTab(this.activeTabValue)
    this.updateTabStyles()
  }

  selectTab(event) {
    event.preventDefault()
    const tab = event.currentTarget.dataset.tabsTab
    this.activeTabValue = tab
    this.showTab(tab)
    this.updateTabStyles()
    this.resetFrame(event.currentTarget)
  }

  // Optional per-tab hook: a tab link may declare a turbo-frame to reset to a
  // given URL whenever it's selected, so the panel always reopens in its
  // initial state instead of whatever it was last navigated to (e.g. the tax
  // report frame returns to its uncalculated resting state on every visit).
  resetFrame(link) {
    const frameId = link.dataset.tabsResetFrame
    const src = link.dataset.tabsResetSrc
    if (!frameId || !src) return

    const frame = document.getElementById(frameId)
    // Setting src only reloads when it differs from the current value; if the
    // frame is already at the reset URL it's already in its initial state.
    if (frame && frame.getAttribute("src") !== src) frame.src = src
  }

  showTab(tab) {
    this.element.querySelectorAll("[data-tab-section]").forEach(section => {
      section.style.display = section.dataset.tabSection === tab ? "block" : "none"
    })
  }

  updateTabStyles() {
    const activeTab = this.activeTabValue

    this.element.querySelectorAll("nav a[data-tabs-tab]").forEach(tab => {
      tab.classList.toggle("tab-link-active", tab.dataset.tabsTab === activeTab)
    })
  }
}
