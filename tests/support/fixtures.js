const base = require('@playwright/test');
const { createProperty, createAgreement } = require('./helpers');

let counter = 0;
function uniqueEmail(tag = 'landlord') {
  counter += 1;
  return `${tag}+${Date.now()}-${counter}@example.com`;
}

const PASSWORD = 'password123';

/**
 * Layered fixtures: `landlord` signs up a fresh account, `property` builds a
 * property on top of it, `agreement` builds an active agreement on top of
 * that. Each fixture yields the URL of the resource it created so tests can
 * navigate to a known state explicitly instead of relying on browser history.
 */
exports.test = base.test.extend({
  landlord: async ({ page }, use) => {
    const email = uniqueEmail();
    await page.goto('/users/sign_up');
    await page.getByRole('textbox', { name: 'Email' }).fill(email);
    await page.getByRole('textbox', { name: 'Password', exact: true }).fill(PASSWORD);
    await page.getByRole('textbox', { name: 'Password confirmation' }).fill(PASSWORD);
    await page.getByRole('button', { name: 'Sign up' }).click();
    await page.waitForURL('**/properties');

    await use({ email, password: PASSWORD });
  },

  property: async ({ page, landlord }, use) => {
    const url = await createProperty(page, 'Maple Street, Unit 4A');
    await use(url);
  },

  agreement: async ({ page, property }, use) => {
    await page.goto(property);
    const url = await createAgreement(page, { startDate: '2020-01-01', endDate: '2099-12-31', rent: 1500 });
    await use(url);
  },
});

exports.expect = base.expect;
exports.uniqueEmail = uniqueEmail;
exports.PASSWORD = PASSWORD;
