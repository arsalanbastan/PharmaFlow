import {
  ADMIN_DASHBOARD_RELEASE,
  hardDeleteForm,
  invoicePaginationWindow,
  layout,
} from './admin-view';

describe('full admin dashboard view', () => {
  it('exposes the exact release marker and every manager section', () => {
    const html = layout('test', '<main>ok</main>', 'dashboard');

    expect(ADMIN_DASHBOARD_RELEASE).toBe(
      'manager-web-excel-pdf-export-v8-20260901',
    );
    expect(html).toContain('/admin/invoices');
    expect(html).toContain('/admin/catalog');
    expect(html).toContain('/admin/companies');
    expect(html).toContain('/admin/bank-accounts');
    expect(html).toContain('/admin/cheques');
    expect(html).toContain('/admin/cash-payments');
    expect(html).toContain('/admin/users');
    expect(html).toContain('/admin/orders');
    expect(html).toContain('/admin/audit-logs');
  });


  it('limits invoice page numbers to ten and exposes ellipses around the window', () => {
    expect(invoicePaginationWindow(50, 100, 10)).toEqual({
      pages: [46, 47, 48, 49, 50, 51, 52, 53, 54, 55],
      showLeadingEllipsis: true,
      showTrailingEllipsis: true,
    });

    expect(invoicePaginationWindow(1, 100, 10)).toEqual({
      pages: [1, 2, 3, 4, 5, 6, 7, 8, 9, 10],
      showLeadingEllipsis: false,
      showTrailingEllipsis: true,
    });

    expect(invoicePaginationWindow(100, 100, 10)).toEqual({
      pages: [91, 92, 93, 94, 95, 96, 97, 98, 99, 100],
      showLeadingEllipsis: true,
      showTrailingEllipsis: false,
    });
  });

  it('requires an explicit DELETE confirmation for hard deletion', () => {
    const html = layout(
      'test',
      hardDeleteForm(
        '/admin/orders/id/hard-delete',
        'csrf-token',
        'test item',
      ),
      'orders',
    );

    expect(html).toContain('name="_confirmation"');
    expect(html).toMatch(/answer\s*!==\s*'DELETE'/);
    expect(html).toContain('حذف دائمی');
  });

  it('disables blocked destructive operations', () => {
    const html = hardDeleteForm(
      '/admin/companies/id/hard-delete',
      'csrf-token',
      'company',
      'has dependencies',
    );

    expect(html).toContain('disabled');
    expect(html).toContain('has dependencies');
  });
});
