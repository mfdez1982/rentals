const { test, expect } = require('../support/fixtures');
const { test: base } = require('@playwright/test');

base.describe('404 page', () => {
  base('shows a custom not-found page for an unknown route', async ({ page }) => {
    const response = await page.goto('/this-route-does-not-exist');
    expect(response.status()).toBe(404);
    await expect(page.getByRole('heading', { name: 'Page not found' })).toBeVisible();
    await expect(page.getByRole('link', { name: '← Go back to home' })).toHaveAttribute('href', '/');
  });
});

test.describe('Turbo-frame direct navigation', () => {
  test('directly navigating to a property edit URL renders the full page, not a bare fragment', async ({
    page,
    property,
  }) => {
    await page.goto(`${property}/edit`);
    await expect(page).toHaveURL(new RegExp(`${property.split('/').pop()}$`));
    await expect(page.getByRole('link', { name: '← My Properties' })).toBeVisible();
    await expect(page.getByRole('heading', { name: 'Maple Street, Unit 4A' })).toBeVisible();
  });

  test('directly navigating to a new-rental-agreement URL renders the full page, not a bare fragment', async ({
    page,
    property,
  }) => {
    const propertyId = property.split('/').pop();
    await page.goto(`${property}/rental_agreements/new`);
    await expect(page).toHaveURL(new RegExp(`properties/${propertyId}$`));
    await expect(page.getByRole('link', { name: '← My Properties' })).toBeVisible();
    await expect(page.getByRole('heading', { name: 'Deductible Expenses', level: 2 })).toBeVisible();
  });
});
