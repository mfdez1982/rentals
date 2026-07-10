const { test, expect } = require('../support/fixtures');
const { addExpense } = require('../support/helpers');

async function switchLanguage(page, code) {
  await page.getByRole('button', { name: /Language|Idioma/ }).click();
  await page.getByRole('button', { name: code, exact: true }).click();
}

test.describe('Internationalization (EN/ES)', () => {
  test('switching to Spanish translates the properties dashboard', async ({ page, landlord }) => {
    await switchLanguage(page, 'ES');
    await expect(page.getByRole('heading', { name: 'Mis Propiedades' })).toBeVisible();
    await page.getByRole('button', { name: 'Añadir Propiedad' }).first().click();
    await expect(page.getByRole('button', { name: 'Crear Propiedad' })).toBeVisible();
  });

  test('the rental agreement submit button is translated in Spanish', async ({ page, property }) => {
    await switchLanguage(page, 'ES');
    await page.getByRole('button', { name: 'Nuevo Contrato de Alquiler' }).click();
    await expect(page.getByRole('button', { name: 'Crear Contrato de Alquiler' })).toBeVisible();
  });

  test('the expense form submit button and category options are translated in Spanish', async ({
    page,
    property,
  }) => {
    await switchLanguage(page, 'ES');
    await page.getByRole('button', { name: 'Gastos Deducibles' }).click();
    await expect(page.getByRole('button', { name: 'Crear Gasto' })).toBeVisible();

    const options = await page.getByLabel('Categoría').locator('option').allTextContents();
    expect(options).toEqual(
      expect.arrayContaining(['Impuestos', 'Seguro', 'Servicios', 'Cuotas de comunidad', 'Otro'])
    );
  });

  test('"View invoice" and category labels are translated for an existing expense', async ({ page, property }) => {
    await addExpense(page, {
      date: '2024-03-15',
      category: 'Insurance',
      amount: 100,
      invoiceUrl: 'https://example.com/invoice.pdf',
    });

    await switchLanguage(page, 'ES');
    // "Seguro" also appears as a <select> option (still in the DOM even though
    // closed), so this is scoped to the table cell to avoid ambiguity.
    await expect(page.getByRole('cell', { name: 'Seguro', exact: true })).toBeVisible();
    await expect(page.getByRole('link', { name: 'Ver factura' })).toBeVisible();
  });

  test('switching back to English restores the original labels', async ({ page, landlord }) => {
    await switchLanguage(page, 'ES');
    await expect(page.getByRole('heading', { name: 'Mis Propiedades' })).toBeVisible();

    await switchLanguage(page, 'EN');
    await expect(page.getByRole('heading', { name: 'My Properties' })).toBeVisible();
  });
});
