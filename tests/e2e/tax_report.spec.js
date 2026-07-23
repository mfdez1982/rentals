const { test, expect } = require('../support/fixtures');
const { createAgreement, addPayments, addExpense } = require('../support/helpers');

// All fixture dates below are fixed in the past (2023) rather than relative to
// "today", so the pro-rata math is fully deterministic regardless of when the
// suite runs. 2023 is not a leap year: Jul 1 -> Dec 31 spans exactly 184 days
// out of 365, giving the same 50.41% ratio the app produces for any property
// active for that same July-December span in a non-leap year.

// Generates a report for the given year from the tax_reports index and waits
// for the saved-reports row to appear.
async function generateReport(page, property, year) {
  await page.goto(`${property}/tax_reports`);
  await page.getByLabel('Select Year:').selectOption(String(year));
  await page.getByRole('button', { name: 'Generate' }).click();
  await page.locator('table tbody tr', { hasText: String(year) }).first().waitFor();
}

test.describe('Tax report', () => {
  test('generating a full calendar year of active rental persists a 100% report', async ({ page, property }) => {
    await createAgreement(page, { startDate: '2023-01-01', endDate: '2023-12-31', rent: 1000 });
    await addPayments(page, { startDate: '2023-01-01', months: 2, amount: 1000 });

    await generateReport(page, property, 2023);

    // The saved-reports row summarizes the report at a glance.
    const row = page.locator('table tbody tr', { hasText: '2023' });
    await expect(row.getByText('$2,000.00')).toBeVisible(); // 2 payments x $1,000

    // Opening it shows the full persisted document.
    await row.getByRole('link', { name: 'Open' }).click();
    await page.waitForURL(/\/tax_reports\/\d+$/);
    await expect(page.getByText('365', { exact: true })).toBeVisible();
    await expect(page.getByText('out of 365 days in 2023')).toBeVisible();
    await expect(page.getByText('100.00%', { exact: true })).toBeVisible();
    await expect(page.getByText('$2,000.00')).toBeVisible();
  });

  test('a partial-year report persists the expected pro-rata ratio and deductible amount', async ({
    page,
    property,
  }) => {
    await createAgreement(page, { startDate: '2023-07-01', endDate: '2024-06-30', rent: 1500 });
    await page.goto(property); // createAgreement leaves the page on the agreement show view
    await addExpense(page, { date: '2023-08-01', category: 'Insurance', amount: 600, description: 'Insurance' });

    await generateReport(page, property, 2023);
    await page.getByRole('link', { name: 'Open' }).first().click();
    await page.waitForURL(/\/tax_reports\/\d+$/);

    await expect(page.getByText('184', { exact: true })).toBeVisible();
    await expect(page.getByText('out of 365 days in 2023')).toBeVisible();
    await expect(page.getByText('50.41%', { exact: true })).toBeVisible();

    const row = page.locator('table tbody tr', { hasText: 'Insurance' });
    await expect(row.getByText('$600.00')).toBeVisible(); // original amount
    await expect(row.getByText('$302.46')).toBeVisible(); // 600 * 50.41%
    await expect(page.locator('tfoot')).toContainText('$302.46');
  });

  test('a year with no active agreement generates a zero report', async ({ page, property }) => {
    await createAgreement(page, { startDate: '2023-01-01', endDate: '2023-12-31', rent: 1000 });

    await generateReport(page, property, 2019);
    await page.getByRole('link', { name: 'Open' }).first().click();
    await page.waitForURL(/\/tax_reports\/\d+$/);

    await expect(page.getByText('0.00%', { exact: true })).toBeVisible();
    await expect(page.getByText('$0.00')).toBeVisible();
    await expect(page.getByText('No expenses recorded for 2019.')).toBeVisible();
  });

  test('a report keeps its numbers even after the underlying data changes (immutable snapshot)', async ({
    page,
    property,
  }) => {
    await createAgreement(page, { startDate: '2023-01-01', endDate: '2023-12-31', rent: 1000 });
    await addPayments(page, { startDate: '2023-01-01', months: 2, amount: 1000 });

    await generateReport(page, property, 2023);

    // Add more income for the same year AFTER generating.
    await page.goto(property);
    await addPayments(page, { startDate: '2023-06-01', months: 1, amount: 1000 });

    // Re-open the original report: it still shows the snapshotted $2,000.00.
    await page.goto(`${property}/tax_reports`);
    await page.getByRole('link', { name: 'Open' }).first().click();
    await page.waitForURL(/\/tax_reports\/\d+$/);
    await expect(page.getByText('$2,000.00')).toBeVisible();
    await expect(page.getByText('$3,000.00')).not.toBeVisible();
  });

  test('saved reports can be deleted', async ({ page, property }) => {
    await createAgreement(page, { startDate: '2023-01-01', endDate: '2023-12-31', rent: 1000 });

    await generateReport(page, property, 2023);
    await expect(page.locator('table tbody tr', { hasText: '2023' })).toBeVisible();

    page.once('dialog', (dialog) => dialog.accept());
    await page.getByRole('button', { name: 'Delete' }).first().click();

    await expect(page.getByText('No tax reports generated yet.')).toBeVisible();
  });

  test('a history of multiple reports for the same year is kept', async ({ page, property }) => {
    await createAgreement(page, { startDate: '2023-01-01', endDate: '2023-12-31', rent: 1000 });

    await generateReport(page, property, 2023);
    await page.getByRole('button', { name: 'Generate' }).click();

    await expect(page.locator('table tbody tr', { hasText: '2023' })).toHaveCount(2);
  });

  test('the year dropdown always includes the current and next year, even with no data', async ({
    page,
    property,
  }) => {
    const currentYear = new Date().getFullYear();
    await page.goto(`${property}/tax_reports`);

    const options = await page.getByLabel('Select Year:').locator('option').allTextContents();
    expect(options).toEqual([String(currentYear + 1), String(currentYear)]);
  });

  test('the year dropdown extends back to the earliest rental agreement on record', async ({ page, property }) => {
    const currentYear = new Date().getFullYear();
    await createAgreement(page, { startDate: '2015-06-01', endDate: '2015-12-31', rent: 800 });
    await page.goto(`${property}/tax_reports`);

    const options = await page.getByLabel('Select Year:').locator('option').allTextContents();
    expect(options[0]).toBe(String(currentYear + 1));
    expect(options[options.length - 1]).toBe('2015');
    expect(options).toContain('2016'); // range is contiguous, not just the two endpoints
  });

  test('the year dropdown extends back to the earliest expense on record', async ({ page, property }) => {
    const currentYear = new Date().getFullYear();
    await addExpense(page, { date: '2016-03-01', category: 'Other', amount: 50 });
    await page.goto(`${property}/tax_reports`);

    const options = await page.getByLabel('Select Year:').locator('option').allTextContents();
    expect(options[0]).toBe(String(currentYear + 1));
    expect(options[options.length - 1]).toBe('2016');
  });
});
