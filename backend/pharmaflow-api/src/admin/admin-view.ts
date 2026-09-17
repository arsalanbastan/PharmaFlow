export const ADMIN_DASHBOARD_RELEASE = 'manager-web-excel-pdf-export-v8-20260901';


export function invoicePaginationWindow(
  currentPage: number,
  totalPages: number,
  maxVisible = 10,
): {
  pages: number[];
  showLeadingEllipsis: boolean;
  showTrailingEllipsis: boolean;
} {
  const safeTotalPages = Math.max(1, Math.trunc(totalPages));
  const safeCurrentPage = Math.min(
    Math.max(1, Math.trunc(currentPage)),
    safeTotalPages,
  );
  const visibleCount = Math.max(
    1,
    Math.min(Math.trunc(maxVisible), safeTotalPages),
  );

  let start = Math.max(
    1,
    safeCurrentPage - Math.floor((visibleCount - 1) / 2),
  );
  let end = start + visibleCount - 1;

  if (end > safeTotalPages) {
    end = safeTotalPages;
    start = Math.max(1, end - visibleCount + 1);
  }

  return {
    pages: Array.from({ length: end - start + 1 }, (_, index) => start + index),
    showLeadingEllipsis: start > 1,
    showTrailingEllipsis: end < safeTotalPages,
  };
}

export function escapeHtml(value: unknown): string {
  return String(value ?? '')
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
    .replaceAll("'", '&#039;');
}

export function formatAmount(value: unknown): string {
  const number = Number(value);

  if (!Number.isFinite(number)) {
    return escapeHtml(value);
  }

  return new Intl.NumberFormat('fa-IR').format(number);
}

export function formatDate(value: Date | string | null | undefined): string {
  if (!value) {
    return '—';
  }

  const date = new Date(value);

  if (Number.isNaN(date.getTime())) {
    return escapeHtml(value);
  }

  return new Intl.DateTimeFormat('fa-IR', {
    dateStyle: 'short',
    timeStyle: 'short',
  }).format(date);
}

export function inputDate(value: Date | string | null | undefined): string {
  if (!value) {
    return '';
  }

  const date = new Date(value);
  return Number.isNaN(date.getTime()) ? '' : date.toISOString().slice(0, 10);
}

export function inputDateTime(
  value: Date | string | null | undefined,
): string {
  if (!value) {
    return '';
  }

  const date = new Date(value);
  return Number.isNaN(date.getTime())
    ? ''
    : date.toISOString().slice(0, 16);
}

export function statusBadge(value: unknown): string {
  const status = String(value ?? '').trim().toUpperCase();
  const labels: Record<string, string> = {
    PENDING: 'در انتظار',
    ORDERED: 'سفارش‌شده',
    RECEIVED: 'دریافت‌شده',
    CANCELED: 'لغوشده',
    DELETED: 'حذف‌شده',
    ACTIVE: 'فعال',
    INACTIVE: 'غیرفعال',
    ARCHIVED: 'آرشیوشده',
  };
  const cssClass =
    status === 'RECEIVED' || status === 'ACTIVE'
      ? 'ok'
      : status === 'PENDING' || status === 'ORDERED'
        ? 'warn'
        : status === 'DELETED' || status === 'CANCELED'
          ? 'danger'
          : '';

  return `<span class="badge ${cssClass}">${escapeHtml((labels[status] ?? status) || '—')}</span>`;
}

export function notice(text: string | undefined, danger = false): string {
  const value = String(text ?? '').trim();
  return value
    ? `<div class="notice ${danger ? 'danger' : ''}">${escapeHtml(value)}</div>`
    : '';
}

export function hardDeleteForm(
  action: string,
  csrfToken: string,
  label: string,
  disabledReason?: string,
): string {
  if (disabledReason) {
    return `<button class="button danger" type="button" disabled title="${escapeHtml(disabledReason)}">حذف دائمی</button>`;
  }

  return `
    <form class="inline-form hard-delete-form" method="post" action="${escapeHtml(action)}" data-delete-label="${escapeHtml(label)}">
      <input type="hidden" name="_csrf" value="${escapeHtml(csrfToken)}">
      <input type="hidden" name="_confirmation" value="">
      <button class="button danger" type="submit">حذف دائمی</button>
    </form>
  `;
}

export function layout(title: string, body: string, active = ''): string {
  const nav = [
    ['dashboard', '/admin', 'داشبورد'],
    ['invoices', '/admin/invoices', 'فاکتورها'],
    ['catalog', '/admin/catalog', 'دارو و کالا'],
    ['companies', '/admin/companies', 'شرکت‌ها'],
    ['accounts', '/admin/bank-accounts', 'حساب‌های بانکی'],
    ['cheques', '/admin/cheques', 'چک‌ها'],
    ['cash', '/admin/cash-payments', 'واریزی‌ها'],
    ['users', '/admin/users', 'کاربران'],
    ['orders', '/admin/orders', 'سفارشات'],
    ['audit', '/admin/audit-logs', 'تغییرات'],
  ]
    .map(
      ([key, href, label]) =>
        `<a class="${active === key ? 'active' : ''}" href="${href}">${label}</a>`,
    )
    .join('');

  return `<!doctype html>
<html lang="fa" dir="rtl">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<meta name="pharmaflow-admin-release" content="${ADMIN_DASHBOARD_RELEASE}">
<title>${escapeHtml(title)} | PharmaFlow</title>
<style>
:root{color-scheme:light;--bg:#f3f6f9;--card:#fff;--text:#142033;--muted:#667085;--border:#d9e0e8;--primary:#075f75;--primary-soft:#e4f2f4;--danger:#b42318;--danger-soft:#fff0ee;--ok:#157347;--warning:#966200;--shadow:0 8px 30px rgba(21,40,60,.06)}
*{box-sizing:border-box}
body{margin:0;background:var(--bg);color:var(--text);font-family:Tahoma,Arial,sans-serif;font-size:14px}
header{position:sticky;top:0;z-index:20;background:rgba(255,255,255,.96);backdrop-filter:blur(8px);border-bottom:1px solid var(--border)}
.header-inner{max-width:1550px;margin:auto;padding:13px 18px;display:flex;align-items:center;gap:22px;flex-wrap:wrap}
.brand{font-size:19px;font-weight:800;color:var(--primary)}
.release{font:11px Consolas,monospace;color:var(--muted);direction:ltr}
nav{display:flex;gap:5px;flex:1;flex-wrap:wrap}
nav a{text-decoration:none;color:var(--text);padding:8px 11px;border-radius:9px}
nav a:hover,nav a.active{background:var(--primary-soft);color:var(--primary)}
main{max-width:1550px;margin:22px auto;padding:0 16px 48px}
h1{font-size:24px;margin:0}h2{font-size:18px;margin:0 0 14px}
.page-title{display:flex;align-items:center;gap:12px;flex-wrap:wrap;margin-bottom:18px}
.cards{display:grid;grid-template-columns:repeat(auto-fit,minmax(185px,1fr));gap:14px}
.card{display:block;background:var(--card);border:1px solid var(--border);border-radius:14px;padding:17px;box-shadow:var(--shadow);text-decoration:none;color:inherit}
.card:hover{border-color:#9dbfc7;transform:translateY(-1px)}
.metric{font-size:30px;font-weight:800;margin-top:8px}.muted{color:var(--muted)}
.toolbar{display:flex;gap:12px;justify-content:space-between;align-items:center;margin-bottom:14px;flex-wrap:wrap}
.search{display:flex;gap:8px;min-width:min(100%,470px)}
.filters{display:flex;gap:8px;flex-wrap:wrap}.filters>*{min-width:150px}.invoice-filters,.catalog-filters{margin-bottom:14px;align-items:end}.catalog-filters .field{min-width:145px}.catalog-filters .search-field{min-width:310px;flex:1}.catalog-filters .sort-field{min-width:220px}.catalog-filters .page-size{min-width:130px}.catalog-stats{margin-bottom:16px}.catalog-stat{cursor:default}.catalog-table table{min-width:1700px}.catalog-description{white-space:pre-wrap;line-height:1.9}.invoice-filters .field{min-width:170px}.invoice-filters .field.company{min-width:230px}.invoice-filters .field.page-size{min-width:130px}.pagination{display:flex;align-items:center;gap:6px;justify-content:center;margin-top:14px;flex-wrap:wrap;direction:ltr}.pagination .page-link{min-width:40px;height:38px;padding:7px 10px;border-radius:9px;background:#edf1f5;color:var(--text);text-decoration:none;display:inline-flex;align-items:center;justify-content:center}.pagination .page-link:hover{background:var(--primary-soft);color:var(--primary)}.pagination .page-link.active{background:var(--primary);color:#fff;font-weight:800}.pagination .page-link.disabled{opacity:.4;cursor:not-allowed;pointer-events:none}.pagination .ellipsis{min-width:28px;text-align:center;color:var(--muted);font-weight:700}.pagination-summary{display:flex;justify-content:center;margin-top:9px}.table-meta{display:flex;gap:10px;align-items:center;flex-wrap:wrap;margin:8px 0 14px}
input,select,textarea{width:100%;border:1px solid #c8d1dc;border-radius:9px;padding:10px;font:inherit;background:#fff;color:var(--text)}
input:focus,select:focus,textarea:focus{outline:2px solid #b9dde3;border-color:var(--primary)}
textarea{min-height:95px;resize:vertical}
button,.button{border:0;border-radius:9px;padding:10px 14px;background:var(--primary);color:#fff;text-decoration:none;cursor:pointer;white-space:nowrap;font:inherit;display:inline-flex;align-items:center;justify-content:center}
.button.secondary{background:#edf1f5;color:var(--text)}
.button.danger{background:var(--danger)}
.button:disabled,button:disabled{opacity:.45;cursor:not-allowed}
.table-wrap{overflow:auto;background:#fff;border:1px solid var(--border);border-radius:14px;box-shadow:var(--shadow)}
table{width:100%;border-collapse:collapse;min-width:1050px}
th,td{text-align:right;padding:11px 10px;border-bottom:1px solid #edf0f4;vertical-align:middle;white-space:nowrap}
th{background:#f8fafc;position:sticky;top:0;z-index:2}tr:last-child td{border-bottom:0}tr:hover td{background:#fbfdfe}
.row-actions{display:flex;gap:7px;align-items:center}.inline-form{display:inline-flex;margin:0}
.copy{border:0;background:transparent;color:var(--primary);padding:2px 5px}
.badge{display:inline-block;padding:4px 9px;border-radius:999px;background:#eef2f6}.badge.ok{background:#e7f7ee;color:var(--ok)}.badge.warn{background:#fff4dc;color:var(--warning)}.badge.danger{background:var(--danger-soft);color:var(--danger)}
.form-card{max-width:1050px;background:#fff;border:1px solid var(--border);border-radius:14px;padding:21px;box-shadow:var(--shadow)}
.grid{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:14px}.field.full{grid-column:1/-1}
label{display:block;margin-bottom:6px;font-weight:700}.check-row{display:flex;align-items:center;gap:9px;min-height:42px}.check-row input{width:auto}
.actions{display:flex;gap:9px;margin-top:20px;flex-wrap:wrap}
.danger-zone{max-width:1050px;margin-top:18px;background:var(--danger-soft);border:1px solid #f2b8b2;border-radius:14px;padding:18px}
.danger-zone h2{color:var(--danger)}
.notice{background:#e8f6ee;color:#155c35;border:1px solid #b9dfc8;border-radius:10px;padding:12px 14px;margin-bottom:15px}.notice.danger{background:var(--danger-soft);color:var(--danger);border-color:#f2b8b2}
.audit-json{direction:ltr;text-align:left;white-space:pre-wrap;word-break:break-word;max-width:520px;max-height:300px;overflow:auto;font:11px Consolas,monospace}
details summary{cursor:pointer;color:var(--primary)}.system{direction:ltr;text-align:left;font:12px Consolas,monospace}.dependency{margin:8px 0;color:var(--danger)}
@media(max-width:760px){.grid{grid-template-columns:1fr}.field.full{grid-column:auto}.header-inner{gap:10px}.brand{width:100%}nav{overflow:auto;flex-wrap:nowrap}.search{width:100%}.search input{min-width:0}.form-card{padding:15px}}
</style>
</head>
<body>
<header><div class="header-inner"><div class="brand">PharmaFlow Manager Web</div><nav>${nav}</nav><div class="release">${ADMIN_DASHBOARD_RELEASE}</div></div></header>
<main>${body}</main>
<script>
document.querySelectorAll('[data-copy]').forEach(function(button){button.addEventListener('click',async function(){var text=button.getAttribute('data-copy')||'';try{await navigator.clipboard.writeText(text);var old=button.textContent;button.textContent='✓';setTimeout(function(){button.textContent=old;},900);}catch(_){}});});
document.querySelectorAll('.hard-delete-form').forEach(function(form){form.addEventListener('submit',function(event){var label=form.getAttribute('data-delete-label')||'این رکورد';var answer=window.prompt('حذف دائمی «'+label+'» قابل بازگشت نیست. برای ادامه عبارت DELETE را وارد کنید:','');if(answer!=='DELETE'){event.preventDefault();return;}var input=form.querySelector('input[name="_confirmation"]');if(input){input.value=answer;}});});
</script>
</body>
</html>`;
}
