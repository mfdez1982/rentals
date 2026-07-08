const { test: base, expect } = require('@playwright/test');
const { test } = require('../support/fixtures');
const { uniqueEmail, PASSWORD } = require('../support/fixtures');
const { logout } = require('../support/helpers');

base.describe('Sign up', () => {
  base('creates a landlord account and lands on the properties dashboard', async ({ page }) => {
    const email = uniqueEmail();
    await page.goto('/users/sign_up');
    await page.getByRole('textbox', { name: 'Email' }).fill(email);
    await page.getByRole('textbox', { name: 'Password', exact: true }).fill(PASSWORD);
    await page.getByRole('textbox', { name: 'Password confirmation' }).fill(PASSWORD);
    await page.getByRole('button', { name: 'Sign up' }).click();

    await expect(page).toHaveURL(/\/properties$/);
    await expect(page.getByText('Welcome! You have signed up successfully.')).toBeVisible();
    await expect(page.getByText(email)).toBeVisible();
  });

  base('rejects mismatched password confirmation', async ({ page }) => {
    const email = uniqueEmail();
    await page.goto('/users/sign_up');
    await page.getByRole('textbox', { name: 'Email' }).fill(email);
    await page.getByRole('textbox', { name: 'Password', exact: true }).fill(PASSWORD);
    await page.getByRole('textbox', { name: 'Password confirmation' }).fill('somethingelse');
    await page.getByRole('button', { name: 'Sign up' }).click();

    await expect(page).toHaveURL(/\/users\/sign_up$/);
    await expect(page.getByText("Password confirmation doesn't match Password")).toBeVisible();
  });

  base('rejects a duplicate email', async ({ page }) => {
    const email = uniqueEmail();
    await page.goto('/users/sign_up');
    await page.getByRole('textbox', { name: 'Email' }).fill(email);
    await page.getByRole('textbox', { name: 'Password', exact: true }).fill(PASSWORD);
    await page.getByRole('textbox', { name: 'Password confirmation' }).fill(PASSWORD);
    await page.getByRole('button', { name: 'Sign up' }).click();
    await expect(page).toHaveURL(/\/properties$/);

    await logout(page);
    await page.goto('/users/sign_up');
    await page.getByRole('textbox', { name: 'Email' }).fill(email);
    await page.getByRole('textbox', { name: 'Password', exact: true }).fill(PASSWORD);
    await page.getByRole('textbox', { name: 'Password confirmation' }).fill(PASSWORD);
    await page.getByRole('button', { name: 'Sign up' }).click();

    await expect(page.getByText('Email has already been taken')).toBeVisible();
  });
});

test.describe('Log in / log out', () => {
  test('rejects invalid credentials with a flash message', async ({ page, landlord }) => {
    await logout(page);
    await page.goto('/users/sign_in');
    await page.getByRole('textbox', { name: 'Email' }).fill(landlord.email);
    await page.getByRole('textbox', { name: 'Password' }).fill('wrong-password');
    await page.getByRole('button', { name: 'Log in' }).click();

    await expect(page.getByText('Invalid email or password.')).toBeVisible();
  });

  test('logs in with valid credentials and lands on the dashboard', async ({ page, landlord }) => {
    await logout(page);

    await page.goto('/users/sign_in');
    await page.getByRole('textbox', { name: 'Email' }).fill(landlord.email);
    await page.getByRole('textbox', { name: 'Password' }).fill(landlord.password);
    await page.getByRole('button', { name: 'Log in' }).click();

    await expect(page).toHaveURL(/\/properties$/);
    await expect(page.getByText(landlord.email)).toBeVisible();
  });

  test('offers a "Remember me" checkbox on the login form', async ({ page, landlord }) => {
    await logout(page);
    await page.goto('/users/sign_in');
    await expect(page.getByRole('checkbox', { name: 'Remember me' })).toBeVisible();
  });

  test('visiting sign-in while already authenticated redirects with a notice', async ({ page, landlord }) => {
    await page.goto('/users/sign_in');
    await expect(page).toHaveURL(/\/properties$/);
    await expect(page.getByText('You are already signed in.')).toBeVisible();
  });

  test('logging out redirects to the landing page', async ({ page, landlord }) => {
    await logout(page);
    await expect(page).toHaveURL(/\/landing$/);
  });
});

test.describe('Forgot password', () => {
  test.skip(
    true,
    'Password reset requires a configured mail delivery service, which is not set up in this environment.'
  );

  test('requesting a reset sends instructions without error', async ({ page, landlord }) => {
    await logout(page);
    await page.goto('/users/password/new');
    await page.getByRole('textbox', { name: 'Email' }).fill(landlord.email);
    await page.getByRole('button', { name: 'Send me password reset instructions' }).click();
    await expect(page.getByText(/you will receive an email/i)).toBeVisible();
  });
});

test.describe('Account settings', () => {
  test('shows the edit-account form with a danger zone for account deletion', async ({ page, landlord }) => {
    await page.goto('/users/edit');
    await expect(page.getByRole('textbox', { name: 'Email' })).toHaveValue(landlord.email);
    await expect(page.getByRole('heading', { name: 'Danger Zone' })).toBeVisible();
    await expect(page.getByRole('button', { name: 'Delete account' })).toBeVisible();
  });

  test('deleting the account requires confirming a JS dialog, and can be cancelled', async ({ page, landlord }) => {
    await page.goto('/users/edit');
    page.once('dialog', (dialog) => dialog.dismiss());
    await page.getByRole('button', { name: 'Delete account' }).click();
    // Dismissed: still on the edit page, still authenticated.
    await expect(page).toHaveURL(/\/users\/edit$/);
    await expect(page.getByRole('heading', { name: 'Danger Zone' })).toBeVisible();
  });

  test('deleting the account when confirmed logs the user out', async ({ page, landlord }) => {
    await page.goto('/users/edit');
    page.once('dialog', (dialog) => dialog.accept());
    await page.getByRole('button', { name: 'Delete account' }).click();
    await expect(page).toHaveURL(/\/landing$/);

    // The account is gone: logging in again with the same credentials fails.
    await page.goto('/users/sign_in');
    await page.getByRole('textbox', { name: 'Email' }).fill(landlord.email);
    await page.getByRole('textbox', { name: 'Password' }).fill(landlord.password);
    await page.getByRole('button', { name: 'Log in' }).click();
    await expect(page.getByText('Invalid email or password.')).toBeVisible();
  });
});
