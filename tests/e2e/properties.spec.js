const { test, expect } = require('../support/fixtures');
const { createProperty, createAgreement } = require('../support/helpers');

test.describe('Properties', () => {
  test('shows an empty state before any property exists', async ({ page, landlord }) => {
    await expect(page.getByText('No properties yet.')).toBeVisible();
  });

  test('creates a property and lists it with an Available status', async ({ page, landlord }) => {
    await page.getByRole('textbox', { name: 'Name' }).fill('Maple Street, Unit 4A');
    await page.getByRole('button', { name: 'Create Property' }).click();

    const row = page.locator('table tbody tr', { hasText: 'Maple Street, Unit 4A' });
    await expect(row).toBeVisible();
    await expect(row.getByText('Available')).toBeVisible();
  });

  test('shows Rented status once the property has an active agreement', async ({ page, landlord }) => {
    const url = await createProperty(page, 'Oak Avenue');
    await createAgreement(page, { startDate: '2020-01-01', endDate: '2099-12-31', rent: 1000 });

    await page.goto('/properties');
    const row = page.locator('table tbody tr', { hasText: 'Oak Avenue' });
    await expect(row.getByText('Rented')).toBeVisible();
  });

  test('property show page allows renaming the property inline', async ({ page, landlord }) => {
    await createProperty(page, 'Original Name');
    await page.getByRole('button', { name: 'Edit' }).click();
    const input = page.locator('input[name="property[name]"]');
    await input.fill('Renamed Property');
    await input.press('Enter');

    await expect(page.getByRole('heading', { name: 'Renamed Property' })).toBeVisible();
    await page.goto('/properties');
    await expect(page.getByRole('link', { name: 'Renamed Property' })).toBeVisible();
  });

  test('deletes a property after confirming the dialog', async ({ page, landlord }) => {
    await createProperty(page, 'To Be Deleted');
    await page.goto('/properties');

    const row = page.locator('table tbody tr', { hasText: 'To Be Deleted' });
    page.once('dialog', (dialog) => {
      expect(dialog.message()).toContain('To Be Deleted');
      dialog.accept();
    });
    await row.getByRole('button', { name: 'Delete' }).click();

    await expect(row).toBeHidden();
    await expect(page.getByText('No properties yet.')).toBeVisible();
  });

  test('cancelling the delete confirmation keeps the property', async ({ page, landlord }) => {
    await createProperty(page, 'Keep Me');
    await page.goto('/properties');

    const row = page.locator('table tbody tr', { hasText: 'Keep Me' });
    page.once('dialog', (dialog) => dialog.dismiss());
    await row.getByRole('button', { name: 'Delete' }).click();

    await expect(row).toBeVisible();
  });
});
