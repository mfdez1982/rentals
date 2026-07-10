const { test, expect } = require('../support/fixtures');
const { createAgreement, formatUsDate } = require('../support/helpers');

test.describe('Rental agreements', () => {
  test('shows an empty state before any agreement exists', async ({ page, property }) => {
    await expect(page.getByText('No agreements yet.')).toBeVisible();
  });

  test('creates an agreement and shows it as Active', async ({ page, property }) => {
    await createAgreement(page, { startDate: '2020-01-01', endDate: '2099-12-31', rent: 1500 });
    await page.goto(property);

    const row = page.locator('table tbody tr', { hasText: formatUsDate('2020-01-01') });
    await expect(row).toBeVisible();
    await expect(row.getByText('Active')).toBeVisible();
    await expect(row.getByText('$1,500.00')).toBeVisible();
  });

  test('renew pre-fills the start date and rent from the source agreement', async ({ page, property }) => {
    await createAgreement(page, { startDate: '2020-01-01', endDate: '2020-12-31', rent: 1200 });
    await page.goto(property);

    await page.getByRole('link', { name: 'Renew' }).click();
    await expect(page.getByRole('textbox', { name: 'Start Date' })).toHaveValue('2021-01-01');
    await expect(page.getByRole('spinbutton', { name: 'Monthly Rent' })).toHaveValue('1200.0');
  });

  test('monthly rent is inline-editable on the agreement show page', async ({ page, agreement }) => {
    await page.goto(agreement);
    await page.getByRole('button', { name: 'Edit' }).click();
    const input = page.locator('input[name="rental_agreement[rent_amount]"]');
    await input.fill('1750');
    await input.press('Enter');

    await expect(page.getByText('$1,750.00/mo')).toBeVisible();
  });

  test('date range is inline-editable via double-click on the heading', async ({ page, agreement }) => {
    await page.goto(agreement);
    await page.getByRole('heading', { level: 1 }).dblclick();

    const startInput = page.locator('input[name="rental_agreement[start_date]"]');
    const endInput = page.locator('input[name="rental_agreement[end_date]"]');
    await startInput.fill('2021-02-01');
    await endInput.fill('2098-12-31');
    await endInput.press('Enter');

    await expect(page.getByRole('heading', { name: '01/02/2021 – 31/12/2098' })).toBeVisible();
  });

  test('deletes an agreement after confirming the dialog', async ({ page, property }) => {
    await createAgreement(page, { startDate: '2020-01-01', endDate: '2099-12-31', rent: 1000 });
    await page.goto(property);

    page.once('dialog', (dialog) => dialog.accept());
    await page.getByRole('button', { name: 'Delete' }).click();

    await expect(page.getByText('No agreements yet.')).toBeVisible();
  });

  test('rejects an end date before the start date', async ({ page, property }) => {
    await page.getByRole('button', { name: 'New Rental Agreement' }).click();
    await page.getByRole('textbox', { name: 'Start Date' }).fill('2020-06-01');
    await page.getByRole('textbox', { name: 'End Date' }).fill('2020-01-01');
    await page.getByRole('spinbutton', { name: 'Monthly Rent' }).fill('1000');
    await page.getByRole('button', { name: 'Create Rental Agreement' }).click();

    await expect(page.getByText(/must be after start date/i)).toBeVisible();
  });

  test('rejects overlapping agreements for the same property', async ({ page, property }) => {
    await createAgreement(page, { startDate: '2020-01-01', endDate: '2020-12-31', rent: 1000 });
    await page.goto(property);

    await page.getByRole('button', { name: 'New Rental Agreement' }).click();
    await page.getByRole('textbox', { name: 'Start Date' }).fill('2020-06-01');
    await page.getByRole('textbox', { name: 'End Date' }).fill('2021-06-01');
    await page.getByRole('spinbutton', { name: 'Monthly Rent' }).fill('1000');
    await page.getByRole('button', { name: 'Create Rental Agreement' }).click();

    await expect(page.getByText(/overlaps with an existing agreement/i)).toBeVisible();
  });
});
