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
