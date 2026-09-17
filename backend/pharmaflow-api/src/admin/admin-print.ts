export type PrintCell = string | number | boolean | null | undefined;

function escapeHtml(value: unknown): string {
  return String(value ?? '')
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#39;');
}

function text(value: PrintCell): string {
  if (value == null) {
    return '';
  }
  if (typeof value === 'boolean') {
    return value ? 'بله' : 'خیر';
  }
  return String(value);
}

export function buildPrintToPdfReport(
  title: string,
  headers: string[],
  rows: PrintCell[][],
  subtitle = '',
): string {
  if (headers.length === 0) {
    throw new Error('PDF report requires at least one column.');
  }

  const body = rows
    .map((row) => {
      const cells = Array.from({ length: headers.length }, (_, index) =>
        `<td>${escapeHtml(text(row[index]))}</td>`,
      ).join('');
      return `<tr>${cells}</tr>`;
    })
    .join('');

  const emptyRow = `<tr><td colspan="${headers.length}" class="empty">رکوردی برای این فیلترها وجود ندارد.</td></tr>`;
  const generatedAt = new Date().toISOString().replace('T', ' ').slice(0, 19);

  return `<!doctype html>
<html lang="fa" dir="rtl">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>${escapeHtml(title)} - PharmaFlow PDF</title>
<style>
  * { box-sizing: border-box; }
  html, body { margin: 0; padding: 0; background: #fff; color: #111827; }
  body { font-family: Tahoma, Arial, "Segoe UI", sans-serif; direction: rtl; padding: 12px; }
  .no-print { display: flex; gap: 8px; align-items: center; flex-wrap: wrap; margin-bottom: 12px; padding: 10px; border: 1px solid #d1d5db; border-radius: 8px; background: #f9fafb; }
  .no-print button { cursor: pointer; border: 0; border-radius: 7px; padding: 9px 14px; font: inherit; background: #111827; color: white; }
  .no-print button.secondary { background: #e5e7eb; color: #111827; }
  .hint { font-size: 12px; color: #4b5563; }
  .report-head { margin-bottom: 12px; }
  h1 { font-size: 20px; margin: 0 0 5px; }
  .meta { font-size: 11px; color: #4b5563; display: flex; gap: 14px; flex-wrap: wrap; }
  table { width: 100%; border-collapse: collapse; table-layout: auto; font-size: 9px; }
  thead { display: table-header-group; }
  tr { break-inside: avoid; page-break-inside: avoid; }
  th, td { border: 1px solid #9ca3af; padding: 4px 5px; text-align: right; vertical-align: top; overflow-wrap: anywhere; }
  th { background: #f3f4f6; font-weight: 700; }
  tbody tr:nth-child(even) { background: #fafafa; }
  .empty { text-align: center; padding: 18px; }
  @page { size: A4 landscape; margin: 8mm; }
  @media print {
    body { padding: 0; -webkit-print-color-adjust: exact; print-color-adjust: exact; }
    .no-print { display: none !important; }
    a { color: inherit; text-decoration: none; }
  }
</style>
</head>
<body>
  <div class="no-print">
    <button type="button" onclick="window.print()">ذخیره / چاپ PDF</button>
    <button type="button" class="secondary" onclick="window.close()">بستن</button>
    <span class="hint">در پنجره چاپ، مقصد را روی Save as PDF / ذخیره به‌صورت PDF قرار دهید.</span>
  </div>
  <div class="report-head">
    <h1>${escapeHtml(title)}</h1>
    <div class="meta">
      <span>تعداد رکورد: ${rows.length.toLocaleString('fa-IR')}</span>
      ${subtitle ? `<span>${escapeHtml(subtitle)}</span>` : ''}
      <span>زمان تهیه: ${escapeHtml(generatedAt)}</span>
    </div>
  </div>
  <table>
    <thead><tr>${headers.map((header) => `<th>${escapeHtml(header)}</th>`).join('')}</tr></thead>
    <tbody>${body || emptyRow}</tbody>
  </table>
<script>
  window.addEventListener('load', () => {
    window.setTimeout(() => window.print(), 350);
  });
</script>
</body>
</html>`;
}
