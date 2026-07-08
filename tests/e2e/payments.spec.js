const { test, expect } = require('../support/fixtures');
const { addPayments } = require('../support/helpers');

function isoDate(date) {
  return date.toISOString().slice(0, 10);
}

function monthsAgo(n) {
  const d = new Date();
  d.setDate(1); // avoid month-length rollover surprises
  d.setMonth(d.getMonth() - n);
  return isoDate(d);
}

test.describe('Payments', () => {
  test('shows an empty state before any payment exists', async ({ page, agreement }) => {
    await page.goto(agreement);
    await expect(page.getByText('No payments recorded yet. Add one below.')).toBeVisible();
  });

  test('bulk-creates one payment per month from a start date', async ({ page, agreement }) => {
    await page.goto(agreement);
    await addPayments(page, { startDate: monthsAgo(6), months: 3, amount: 1000 });

    const rows = page.locator('table tbody tr');
    await expect(rows).toHaveCount(3);
    await expect(page.getByText('$1,000.00').first()).toBeVisible();
  });

  test('marks a past-due, unpaid payment as Overdue with a summary banner', async ({ page, agreement }) => {
    await page.goto(agreement);
    await addPayments(page, { startDate: monthsAgo(3), months: 2, amount: 1000 });

    await expect(page.getByText('Overdue').first()).toBeVisible();
    await expect(page.getByText(/\d+ overdue payments?/)).toBeVisible();
  });

  test('a future payment with no paid date shows Unpaid, not Overdue', async ({ page, agreement }) => {
    await page.goto(agreement);
    const future = new Date();
    future.setMonth(future.getMonth() + 2);
    await addPayments(page, { startDate: isoDate(future), months: 1, amount: 1000 });

    await expect(page.getByText('Unpaid')).toBeVisible();
    await expect(page.getByText(/overdue payment/i)).toBeHidden();
  });

  test('marking an overdue payment paid clears the overdue indicator', async ({ page, agreement }) => {
    await page.goto(agreement);
    await addPayments(page, { startDate: monthsAgo(2), months: 1, amount: 1000 });
    await expect(page.getByText(/overdue payment/i)).toBeVisible();

    await page.locator('table tbody tr').first().getByRole('link', { name: 'Edit' }).click();
    await page.getByRole('textbox', { name: '(leave blank if unpaid)' }).fill(isoDate(new Date()));
    await page.getByRole('button', { name: 'Update Payment' }).click();

    await expect(page.getByText(/overdue payment/i)).toBeHidden();
    await expect(page.getByText('Overdue')).toBeHidden();
  });

  test('an overdue payment marks the agreement and property as having overdue payments', async ({
    page,
    property,
    agreement,
  }) => {
    await page.goto(agreement);
    await addPayments(page, { startDate: monthsAgo(2), months: 1, amount: 1000 });

    await page.goto(property);
    // The property show page also renders a hidden duplicate row-frame (used by
    // the index's inline-edit restore flow) that matches the same text, so this
    // is scoped to the visible agreements section rather than the whole page.
    const propertyId = property.split('/').pop();
    await expect(page.locator(`#agreements_property_${propertyId}`).getByText('Overdue Payments')).toBeVisible();

    await page.goto('/properties');
    await expect(page.getByText('Overdue Payments')).toBeVisible();
  });

  test('deletes a payment after confirming the dialog', async ({ page, agreement }) => {
    await page.goto(agreement);
    await addPayments(page, { startDate: monthsAgo(1), months: 1, amount: 1000 });

    page.once('dialog', (dialog) => dialog.accept());
    await page.locator('table tbody tr').first().getByRole('button', { name: 'Delete' }).click();

    await expect(page.getByText('No payments recorded yet. Add one below.')).toBeVisible();
  });
});
