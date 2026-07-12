import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { activeTab: String }

  connect() {
    this.showTab(this.activeTabValue)
    this.updateTabStyles()
  }

  selectTab(event) {
    event.preventDefault()
    const tab = event.currentTarget.dataset.tabsTab
    this.activeTabValue = tab
    this.showTab(tab)
    this.updateTabStyles()
  }

  showTab(tab) {
    this.element.querySelectorAll("[data-tab-section]").forEach(section => {
      section.style.display = section.dataset.tabSection === tab ? "block" : "none"
    })
  }

  updateTabStyles() {
    const activeTab = this.activeTabValue

    this.element.querySelectorAll("nav a[data-tabs-tab]").forEach(tab => {
      const isActive = tab.dataset.tabsTab === activeTab
      if (isActive) {
        tab.className = "text-sm pb-3 transition-colors inline-block text-primary font-bold border-b-2 border-primary"
      } else {
        tab.className = "text-sm pb-3 transition-colors inline-block text-base-content/60 font-normal hover:text-base-content"
      }
    })
  }
}
