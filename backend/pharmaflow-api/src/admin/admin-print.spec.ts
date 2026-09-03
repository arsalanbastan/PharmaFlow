import { buildPrintToPdfReport } from './admin-print';

describe('admin print-to-PDF report', () => {
  it('renders a printable Persian table and safely escapes cell content', () => {
    const html = buildPrintToPdfReport(
      'دارو و کالا',
      ['نام', 'قیمت'],
      [
        ['آموکسی‌سیلین', 125000],
        ['<script>alert(1)</script>', 0],
      ],
      'فقط نتایج فیلترشده',
    );

    expect(html).toContain('lang="fa" dir="rtl"');
    expect(html).toContain('آموکسی‌سیلین');
    expect(html).toContain('&lt;script&gt;alert(1)&lt;/script&gt;');
    expect(html).not.toContain('<script>alert(1)</script>');
    expect(html).toContain('@page { size: A4 landscape;');
    expect(html).toContain('window.print()');
    expect(html).toContain('Save as PDF');
  });
});
