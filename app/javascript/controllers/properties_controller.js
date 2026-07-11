import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { activeTab: { type: String, default: "contratos" } }

  connect() {
    this.restoreTabState()
    this.showTab(this.activeTabValue)
    this.updateTabStyles()
    this.setupTurboHandlers()
  }

  restoreTabState() {
    // First, try to get tab from URL parameter
    const params = new URLSearchParams(window.location.search)
    const tabParam = params.get("tab")

    if (tabParam) {
      this.activeTabValue = tabParam
      sessionStorage.setItem("propertyTabState", tabParam)
    } else {
      // Fall back to sessionStorage if URL param doesn't exist
      const sessionTab = sessionStorage.getItem("propertyTabState")
      if (sessionTab) {
        this.activeTabValue = sessionTab
        // Update URL to match
        this.updateUrl(sessionTab)
      }
    }
  }

  setupTurboHandlers() {
    document.addEventListener("turbo:before-visit", (event) => {
      // Preserve tab state across navigation
      const currentTab = this.activeTabValue
      sessionStorage.setItem("propertyTabState", currentTab)
    })

    document.addEventListener("turbo:load", () => {
      // Restore tab state after page load
      const savedTab = sessionStorage.getItem("propertyTabState")
      if (savedTab && this.element) {
        this.activeTabValue = savedTab
        this.updateUrl(savedTab)
        this.showTab(savedTab)
        this.updateTabStyles()
      }
    })
  }

  selectTab(event) {
    event.preventDefault()
    const tab = event.currentTarget.dataset.propertiesTab
    this.activeTabValue = tab
    sessionStorage.setItem("propertyTabState", tab)
    this.updateUrl(tab)
    this.showTab(tab)
    this.updateTabStyles()
  }

  updateUrl(tab) {
    const params = new URLSearchParams(window.location.search)
    params.set("tab", tab)
    const newUrl = `${window.location.pathname}?${params.toString()}`
    window.history.pushState({ tab }, "", newUrl)
  }

  showTab(tab) {
    document.querySelectorAll("[data-property-section]").forEach(section => {
      section.style.display = section.dataset.propertySection === tab ? "block" : "none"
    })
  }

  updateTabStyles() {
    const container = this.element
    const tabs = container.querySelectorAll("nav a[data-properties-tab]")
    const activeTab = this.activeTabValue

    tabs.forEach(tab => {
      const isActive = tab.dataset.propertiesTab === activeTab
      if (isActive) {
        tab.className = "text-sm pb-3 transition-colors inline-block text-primary font-bold border-b-2 border-primary"
      } else {
        tab.className = "text-sm pb-3 transition-colors inline-block text-base-content/60 font-normal hover:text-base-content"
      }
    })
  }

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
