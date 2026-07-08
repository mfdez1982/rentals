const { test, expect } = require('../support/fixtures');
const { addExpense } = require('../support/helpers');

test.describe('Deductible expenses', () => {
  test('shows an empty state before any expense exists', async ({ page, property }) => {
    await expect(page.getByText(/No expenses recorded for \d{4}\./)).toBeVisible();
  });

  test('creates an expense with a category, description, and invoice link', async ({ page, property }) => {
    await addExpense(page, {
      date: '2024-03-15',
      category: 'Insurance',
      amount: 600,
      description: 'Annual home insurance renewal',
      invoiceUrl: 'https://example.com/invoice.pdf',
    });

    const row = page.locator('table tbody tr', { hasText: 'Annual home insurance renewal' });
    await expect(row).toBeVisible();
    await expect(row.getByText('Insurance', { exact: true })).toBeVisible();
    await expect(row.getByText('$600.00')).toBeVisible();
    await expect(row.getByRole('link', { name: 'View invoice' })).toHaveAttribute(
      'href',
      'https://example.com/invoice.pdf'
    );
  });

  test('creates an expense without the optional description or invoice URL', async ({ page, property }) => {
    await addExpense(page, { date: '2024-03-15', category: 'Utilities', amount: 80 });

    const row = page.locator('table tbody tr', { hasText: 'Utilities' });
    await expect(row).toBeVisible();
    await expect(row.getByRole('link', { name: 'View invoice' })).toHaveCount(0);
  });

  test('offers every expense category in the dropdown', async ({ page, property }) => {
    const options = await page.getByLabel('Category').locator('option').allTextContents();
    expect(options).toEqual(
      expect.arrayContaining([
        'Tax',
        'Insurance',
        'Utilities',
        'Community fees',
        'Repairs & maintenance',
        'Management & legal',
        'Financing',
        'Other',
      ])
    );
  });

  test('edits an existing expense', async ({ page, property }) => {
    await addExpense(page, { date: '2024-03-15', category: 'Tax', amount: 100, description: 'Original' });

    await page.locator('table tbody tr', { hasText: 'Original' }).getByRole('link', { name: 'Edit' }).click();

    // Scoped to the edit form specifically: the "Create Expense" form at the
    // bottom of the page has its own identically-labeled Description field,
    // and an unscoped locator would ambiguously match either one.
    const editForm = page.locator('form', { has: page.getByRole('button', { name: 'Update Expense' }) });
    await editForm.getByRole('textbox', { name: 'Description (optional)' }).fill('Updated description');
    await editForm.getByRole('button', { name: 'Update Expense' }).click();

    await expect(page.getByText('Updated description')).toBeVisible();
  });

  test('rejects an invalid invoice URL', async ({ page, property }) => {
    await page.getByRole('textbox', { name: 'Date', exact: true }).fill('2024-03-15');
    await page.getByLabel('Category').selectOption({ label: 'Other' });
    await page.getByRole('spinbutton', { name: 'Amount' }).fill('50');
    // "ftp://..." is a syntactically valid URL (passes the browser's native
    // type="url" validation) but fails the app's stricter http(s)-only regex,
    // so this actually reaches server-side validation instead of being
    // blocked client-side like a plain non-URL string would be.
    await page.getByRole('textbox', { name: 'Invoice URL (optional)' }).fill('ftp://example.com/invoice.pdf');
    await page.getByRole('button', { name: 'Create Expense' }).click();

    await expect(page.getByText(/must be a valid URL/i)).toBeVisible();
  });

  test('deletes an expense after confirming the dialog', async ({ page, property }) => {
    await addExpense(page, { date: '2024-03-15', category: 'Other', amount: 50, description: 'To delete' });

    const row = page.locator('table tbody tr', { hasText: 'To delete' });
    page.once('dialog', (dialog) => dialog.accept());
    await row.getByRole('button', { name: 'Delete' }).click();

    await expect(page.getByText(/No expenses recorded for \d{4}\./)).toBeVisible();
  });
});
