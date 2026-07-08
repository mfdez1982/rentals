/**
 * Small helpers for building up fixture data through the UI. Each helper
 * assumes `page` is already authenticated (use the `landlord` fixture).
 */

/** Creates a property from the /properties index and returns its show-page URL. */
async function createProperty(page, name) {
  await page.goto('/properties');
  await page.getByRole('textbox', { name: 'Name' }).fill(name);
  await page.getByRole('button', { name: 'Create Property' }).click();
  await page.getByRole('link', { name }).click();
  await page.waitForURL(/\/properties\/\d+$/);
  return page.url();
}

/** Creates a rental agreement on the currently-open property show page. */
async function createAgreement(page, { startDate, endDate, rent }) {
  await page.getByRole('textbox', { name: 'Start Date' }).fill(startDate);
  await page.getByRole('textbox', { name: 'End Date' }).fill(endDate);
  await page.getByRole('spinbutton', { name: 'Monthly Rent' }).fill(String(rent));
  await page.getByRole('button', { name: 'Create Rental Agreement' }).click();
  await page.getByRole('link', { name: formatUsDate(startDate) }).click();
  await page.waitForURL(/\/rental_agreements\/\d+$/);
  return page.url();
}

/**
 * Adds a batch of recurring payments on the currently-open agreement show
 * page, and waits for the first resulting row to actually appear before
 * returning. Submitting is an async Turbo request; without waiting here, a
 * caller that immediately navigates away (or asserts) can race the request
 * and observe pre-submission state (or cancel the request outright).
 */
async function addPayments(page, { startDate, months, amount }) {
  await page.getByRole('textbox', { name: 'Start Date' }).fill(startDate);
  await page.getByRole('spinbutton', { name: 'Number of months' }).fill(String(months));
  await page.getByRole('spinbutton', { name: 'Amount' }).fill(String(amount));
  await page.getByRole('button', { name: 'Add Payments' }).click();
  await page.locator('table tbody tr', { hasText: formatUsDate(startDate) }).first().waitFor();
}

/**
 * Adds a deductible expense on the currently-open property show page, and
 * waits for the resulting row to appear before returning (see addPayments
 * for why this matters).
 */
async function addExpense(page, { date, category, amount, description, invoiceUrl }) {
  await page.getByRole('textbox', { name: 'Date', exact: true }).fill(date);
  await page.getByLabel('Category').selectOption({ label: category });
  await page.getByRole('spinbutton', { name: 'Amount' }).fill(String(amount));
  if (description) {
    await page.getByRole('textbox', { name: 'Description (optional)' }).fill(description);
  }
  if (invoiceUrl) {
    await page.getByRole('textbox', { name: 'Invoice URL (optional)' }).fill(invoiceUrl);
  }
  await page.getByRole('button', { name: 'Create Expense' }).click();
  await page
    .locator('table tbody tr', { hasText: formatUsDate(date) })
    .filter({ hasText: formatCurrency(amount) })
    .first()
    .waitFor();
}

/** Converts an ISO date (YYYY-MM-DD) to the app's DD/MM/YYYY display format. */
function formatUsDate(isoDate) {
  const [y, m, d] = isoDate.split('-');
  return `${d}/${m}/${y}`;
}

/** Converts a plain number to the app's currency display format (e.g. 1500 -> "$1,500.00"). */
function formatCurrency(amount) {
  return `$${Number(amount).toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}`;
}

/** Dismisses the first-visit cookie consent banner, if present, by accepting it. */
async function acceptCookies(page) {
  const banner = page.getByRole('dialog', { name: 'We use cookies' });
  if (await banner.isVisible().catch(() => false)) {
    await page.getByRole('button', { name: 'Accept', exact: true }).click();
  }
}

/**
 * Logs out and waits for the redirect to /landing to complete. The "Log out"
 * link triggers an async Turbo DELETE request; without waiting for it to
 * finish, a subsequent navigation can race the actual session teardown and
 * land on a page while still authenticated (Devise then redirects away from
 * sign-in/sign-up, and any textbox lookups there time out).
 */
async function logout(page) {
  await page.getByRole('link', { name: 'Log out' }).click();
  await page.waitForURL('**/landing');
}

module.exports = {
  createProperty,
  createAgreement,
  addPayments,
  addExpense,
  formatUsDate,
  formatCurrency,
  acceptCookies,
  logout,
};
