const { test, expect } = require('../support/fixtures');
const { uniqueEmail, PASSWORD } = require('../support/fixtures');
const { createProperty, logout } = require('../support/helpers');

test.describe('Multi-tenancy isolation', () => {
  test('a second landlord sees an empty dashboard, not another landlord\'s properties', async ({
    page,
    landlord,
  }) => {
    await createProperty(page, 'Landlord One Property');
    await logout(page);

    const email = uniqueEmail('landlord2');
    await page.goto('/users/sign_up');
    await page.getByRole('textbox', { name: 'Email' }).fill(email);
    await page.getByRole('textbox', { name: 'Password', exact: true }).fill(PASSWORD);
    await page.getByRole('textbox', { name: 'Password confirmation' }).fill(PASSWORD);
    await page.getByRole('button', { name: 'Sign up' }).click();

    await expect(page).toHaveURL(/\/properties$/);
    await expect(page.getByText('No properties yet.')).toBeVisible();
    await expect(page.getByText('Landlord One Property')).toHaveCount(0);
  });

  test('directly navigating to another landlord\'s property returns a 404, not the data', async ({
    page,
    property,
  }) => {
    const propertyId = property.split('/').pop();
    await logout(page);

    const email = uniqueEmail('landlord2');
    await page.goto('/users/sign_up');
    await page.getByRole('textbox', { name: 'Email' }).fill(email);
    await page.getByRole('textbox', { name: 'Password', exact: true }).fill(PASSWORD);
    await page.getByRole('textbox', { name: 'Password confirmation' }).fill(PASSWORD);
    await page.getByRole('button', { name: 'Sign up' }).click();
    await expect(page).toHaveURL(/\/properties$/);

    const response = await page.goto(`/properties/${propertyId}`);
    expect(response.status()).toBe(404);
    await expect(page.getByRole('heading', { name: 'Page not found' })).toBeVisible();
  });
});
