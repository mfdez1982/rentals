import "@hotwired/turbo-rails"
import "controllers"
import 'https://cdn.jsdelivr.net/gh/orestbida/cookieconsent@3.0.1/dist/cookieconsent.umd.js';

// Configure cookie consent banner
CookieConsent.run({
  disablePageInteraction: true,
  hideFromBots: true,

  cookie: {
    name: 'cc_cookie',
    expiresAfterDays: 365,
  },

  guiOptions: {
    consentModal: {
      layout: 'cloud inline',
      position: 'bottom center',
      equalWeightButtons: true,
      flipButtons: false
    },
    preferencesModal: {
      layout: 'box',
      equalWeightButtons: true,
      flipButtons: false
    }
  },

  categories: {
    necessary: {
      enabled: true,
      readOnly: true
    }
  },

  language: {
    default: 'en',
    translations: {
      en: {
        consentModal: {
          title: 'We use cookies',
          description: 'This website uses essential cookies to manage your session and authentication. We do not collect or track any personal data.',
          acceptAllBtn: 'Accept',
          acceptNecessaryBtn: 'Reject',
          showPreferencesBtn: 'Manage preferences'
        },
        preferencesModal: {
          title: 'Cookie preferences',
          acceptAllBtn: 'Accept all',
          acceptNecessaryBtn: 'Reject all',
          savePreferencesBtn: 'Save preferences',
          closeIconLabel: 'Close modal',
          sections: [
            {
              title: 'Your Privacy',
              description: 'We use cookies to ensure your session stays secure and you remain logged in.'
            },
            {
              title: 'Strictly Necessary',
              description: 'These cookies are essential for the proper functioning of the website and cannot be disabled.',
              linkedCategory: 'necessary'
            }
          ]
        }
      }
    }
  }
});
