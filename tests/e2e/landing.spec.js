const { test, expect } = require('@playwright/test');

// Note: the cookie consent banner (orestbida/cookieconsent) is configured with
// `hideFromBots: true`, which deliberately suppresses it for automated
// browsers like Playwright's. It's untestable here by design and covered by
// manual QA instead.

test.describe('Landing page', () => {
  test('shows marketing content and links to sign up / log in', async ({ page }) => {
    await page.goto('/');
    await expect(page).toHaveURL(/\/landing$/);
    await expect(page.getByRole('heading', { name: 'Property management, minus the chaos' })).toBeVisible();
    await expect(page.getByRole('link', { name: 'Log in' }).first()).toHaveAttribute('href', '/users/sign_in');
    await expect(page.getByRole('link', { name: 'Sign up' }).first()).toHaveAttribute('href', '/users/sign_up');
    await expect(page.getByRole('link', { name: "Get Started — It's Free" }).first()).toHaveAttribute('href', '/users/sign_up');
  });

  test('features grid highlights the three core capabilities', async ({ page }) => {
    await page.goto('/');
    await expect(page.getByRole('heading', { name: 'Effortless Property Tracking' })).toBeVisible();
    await expect(page.getByRole('heading', { name: 'Smart Rental Agreements' })).toBeVisible();
    await expect(page.getByRole('heading', { name: 'Overdue Payment Alerts' })).toBeVisible();
  });

  test('language switcher toggles the landing page into Spanish and back', async ({ page }) => {
    await page.goto('/');
    await page.getByRole('button', { name: 'Language' }).click();
    await page.getByRole('button', { name: 'ES', exact: true }).click();
    await expect(page.getByRole('link', { name: 'Alquileres' }).first()).toBeVisible();

    await page.getByRole('button', { name: 'Idioma' }).click();
    await page.getByRole('button', { name: 'EN', exact: true }).click();
    await expect(page.getByRole('link', { name: 'Rentals' }).first()).toBeVisible();
  });
});
