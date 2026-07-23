const { test, expect } = require('../support/fixtures');
const { createAgreement, addPayments, addExpense } = require('../support/helpers');

// All fixture dates below are fixed in the past (2023) rather than relative to
// "today", so the pro-rata math is fully deterministic regardless of when the
// suite runs. 2023 is not a leap year: Jul 1 -> Dec 31 spans exactly 184 days
// out of 365, giving the same 50.41% ratio the app produces for any property
// active for that same July-December span in a non-leap year.

test.describe('Tax report', () => {
  test('a full calendar year of active rental shows a 100% pro-rata ratio', async ({ page, property }) => {
    await createAgreement(page, { startDate: '2023-01-01', endDate: '2023-12-31', rent: 1000 });
    await addPayments(page, { startDate: '2023-01-01', months: 2, amount: 1000 });

    await page.goto(`${property}/tax_report?year=2023&calculate=1`);

    await expect(page.getByText('365', { exact: true })).toBeVisible();
    await expect(page.getByText('out of 365 days in 2023')).toBeVisible();
    await expect(page.getByText('100.00%', { exact: true })).toBeVisible();
    await expect(page.getByText('$2,000.00')).toBeVisible(); // 2 payments x $1,000
  });

  test('a partial-year agreement produces the expected pro-rata ratio and deductible amount', async ({
    page,
    property,
  }) => {
    await createAgreement(page, { startDate: '2023-07-01', endDate: '2024-06-30', rent: 1500 });
    await page.goto(property); // createAgreement leaves the page on the agreement show view
    await addExpense(page, { date: '2023-08-01', category: 'Insurance', amount: 600, description: 'Insurance' });

    await page.goto(`${property}/tax_report?year=2023&calculate=1`);

    await expect(page.getByText('184', { exact: true })).toBeVisible();
    await expect(page.getByText('out of 365 days in 2023')).toBeVisible();
    await expect(page.getByText('50.41%', { exact: true })).toBeVisible();

    const row = page.locator('table tbody tr', { hasText: 'Insurance' });
    await expect(row.getByText('$600.00')).toBeVisible(); // original amount
    await expect(row.getByText('$302.46')).toBeVisible(); // 600 * 50.41%
    await expect(page.locator('tfoot')).toContainText('$302.46');
  });

  test('a year with no active agreement shows zero across the board', async ({ page, property }) => {
    await createAgreement(page, { startDate: '2023-01-01', endDate: '2023-12-31', rent: 1000 });

    await page.goto(`${property}/tax_report?year=2019&calculate=1`);

    await expect(page.getByText('0', { exact: true }).first()).toBeVisible();
    await expect(page.getByText('0.00%', { exact: true })).toBeVisible();
    await expect(page.getByText('$0.00')).toBeVisible();
    await expect(page.getByText('No expenses recorded for 2019.')).toBeVisible();
  });

  test('the resting state shows only the year selector and a hint, with no report', async ({ page, property }) => {
    await createAgreement(page, { startDate: '2023-01-01', endDate: '2023-12-31', rent: 1000 });
    await page.goto(`${property}/tax_report?year=2023`);

    await expect(page.getByRole('button', { name: 'Calculate' })).toBeVisible();
    await expect(page.getByText('Select a year and click')).toBeVisible();
    await expect(page.getByText('out of 365 days in 2023')).not.toBeVisible();
  });

  test('the year selector dropdown does not auto-navigate; Calculate loads the report for the selected year', async ({
    page,
    property,
  }) => {
    await createAgreement(page, { startDate: '2023-01-01', endDate: '2023-12-31', rent: 1000 });
    await page.goto(`${property}/tax_report?year=2023&calculate=1`);

    await page.getByLabel('Select Year:').selectOption('2024');
    await expect(page).not.toHaveURL(/year=2024/);
    await expect(page.getByLabel('Select Year:')).toHaveValue('2024');

    await page.getByRole('button', { name: 'Calculate' }).click();
    await expect(page).toHaveURL(/year=2024/);
    await expect(page).toHaveURL(/calculate=1/);
    await expect(page.getByText('out of 366 days in 2024')).toBeVisible(); // 2024 is a leap year
  });

  test('the year dropdown always includes the current and next year, even with no data', async ({
    page,
    property,
  }) => {
    const currentYear = new Date().getFullYear();
    await page.goto(`${property}/tax_report`);

    const options = await page.getByLabel('Select Year:').locator('option').allTextContents();
    expect(options).toEqual([String(currentYear + 1), String(currentYear)]);
  });

  test('the year dropdown extends back to the earliest rental agreement on record', async ({ page, property }) => {
    const currentYear = new Date().getFullYear();
    await createAgreement(page, { startDate: '2015-06-01', endDate: '2015-12-31', rent: 800 });
    await page.goto(`${property}/tax_report`);

    const options = await page.getByLabel('Select Year:').locator('option').allTextContents();
    expect(options[0]).toBe(String(currentYear + 1));
    expect(options[options.length - 1]).toBe('2015');
    expect(options).toContain('2016'); // range is contiguous, not just the two endpoints
  });

  test('the year dropdown extends back to the earliest expense on record', async ({ page, property }) => {
    const currentYear = new Date().getFullYear();
    await addExpense(page, { date: '2016-03-01', category: 'Other', amount: 50 });
    await page.goto(`${property}/tax_report`);

    const options = await page.getByLabel('Select Year:').locator('option').allTextContents();
    expect(options[0]).toBe(String(currentYear + 1));
    expect(options[options.length - 1]).toBe('2016');
  });
});
