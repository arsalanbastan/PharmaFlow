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

  if (Number.isNaN(date.getTime())) {
    return '';
  }

  return date.toISOString().slice(0, 10);
}

export function layout(title: string, body: string, active = ''): string {
  const nav = [
    ['dashboard', '/admin', 'داشبورد'],
    ['companies', '/admin/companies', 'شرکت‌ها'],
    ['accounts', '/admin/bank-accounts', 'حساب‌های بانکی'],
    ['cheques', '/admin/cheques', 'چک‌ها'],
    ['audit', '/admin/audit-logs', 'تاریخچه تغییرات'],
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
<title>${escapeHtml(title)} | PharmaFlow</title>

<style>
:root{
  color-scheme:light;
  --bg:#f5f7fa;
  --card:#fff;
  --text:#172033;
  --muted:#6b7280;
  --border:#dde2ea;
  --primary:#1769aa;
  --danger:#b42318;
}

*{box-sizing:border-box}
body{
  margin:0;
  background:var(--bg);
  color:var(--text);
  font-family:Tahoma,Arial,sans-serif;
  font-size:14px;
}
header{
  background:#fff;
  border-bottom:1px solid var(--border);
  padding:14px 22px;
}
.header-inner{
  max-width:1500px;
  margin:auto;
  display:flex;
  align-items:center;
  gap:24px;
  flex-wrap:wrap;
}
.brand{
  font-size:19px;
  font-weight:700;
}
nav{
  display:flex;
  gap:5px;
  flex-wrap:wrap;
}
nav a{
  text-decoration:none;
  color:var(--text);
  padding:8px 12px;
  border-radius:8px;
}
nav a:hover,
nav a.active{
  background:#e8f1f8;
  color:var(--primary);
}
main{
  max-width:1500px;
  margin:22px auto;
  padding:0 16px 40px;
}
h1{
  font-size:23px;
  margin:0 0 18px;
}
.cards{
  display:grid;
  grid-template-columns:repeat(auto-fit,minmax(200px,1fr));
  gap:14px;
}
.card{
  background:var(--card);
  border:1px solid var(--border);
  border-radius:12px;
  padding:18px;
}
.metric{
  font-size:30px;
  font-weight:700;
  margin-top:8px;
}
.muted{color:var(--muted)}
.toolbar{
  display:flex;
  gap:10px;
  justify-content:space-between;
  align-items:center;
  margin-bottom:14px;
  flex-wrap:wrap;
}
.search{
  display:flex;
  gap:8px;
  min-width:min(100%,420px);
}
input,select,textarea{
  width:100%;
  border:1px solid #cbd2dc;
  border-radius:8px;
  padding:10px;
  font:inherit;
  background:#fff;
}
textarea{min-height:90px;resize:vertical}
button,.button{
  border:0;
  border-radius:8px;
  padding:10px 15px;
  background:var(--primary);
  color:white;
  text-decoration:none;
  cursor:pointer;
  white-space:nowrap;
}
.button.secondary{
  background:#eef2f6;
  color:var(--text);
}
.table-wrap{
  overflow:auto;
  background:#fff;
  border:1px solid var(--border);
  border-radius:12px;
}
table{
  width:100%;
  border-collapse:collapse;
  min-width:950px;
}
th,td{
  text-align:right;
  padding:11px 10px;
  border-bottom:1px solid #edf0f4;
  vertical-align:middle;
  white-space:nowrap;
}
th{
  background:#f9fafb;
  position:sticky;
  top:0;
}
tr:last-child td{border-bottom:0}
.copy{
  border:0;
  background:transparent;
  color:var(--primary);
  padding:2px 5px;
}
.badge{
  display:inline-block;
  padding:3px 8px;
  border-radius:999px;
  background:#eef2f6;
}
.badge.ok{background:#e8f7ee;color:#17663a}
.badge.warn{background:#fff4df;color:#8a5600}
.form-card{
  max-width:900px;
  background:#fff;
  border:1px solid var(--border);
  border-radius:12px;
  padding:20px;
}
.grid{
  display:grid;
  grid-template-columns:repeat(2,minmax(0,1fr));
  gap:14px;
}
.field.full{grid-column:1/-1}
label{
  display:block;
  margin-bottom:6px;
  font-weight:600;
}
.actions{
  display:flex;
  gap:10px;
  margin-top:20px;
}
.audit-json{
  direction:ltr;
  text-align:left;
  white-space:pre-wrap;
  word-break:break-word;
  max-width:520px;
  max-height:320px;
  overflow:auto;
  font-family:Consolas,monospace;
  font-size:11px;
}

details summary{
  cursor:pointer;
  color:var(--primary);
}

.system{
  direction:ltr;
  text-align:left;
  font-family:Consolas,monospace;
  font-size:12px;
}
@media(max-width:700px){
  .grid{grid-template-columns:1fr}
  .field.full{grid-column:auto}
}
</style>
</head>

<body>
<header>
  <div class="header-inner">
    <div class="brand">PharmaFlow Admin</div>
    <nav>${nav}</nav>
  </div>
</header>

<main>
${body}
</main>

<script>
document.querySelectorAll('[data-copy]').forEach(function(button){
  button.addEventListener('click', async function(){
    var text = button.getAttribute('data-copy') || '';
    try{
      await navigator.clipboard.writeText(text);
      var old = button.textContent;
      button.textContent = '✓';
      setTimeout(function(){ button.textContent = old; }, 900);
    }catch(_){}
  });
});
</script>
</body>
</html>`;
}
