"use strict";
var __decorate = (this && this.__decorate) || function (decorators, target, key, desc) {
    var c = arguments.length, r = c < 3 ? target : desc === null ? desc = Object.getOwnPropertyDescriptor(target, key) : desc, d;
    if (typeof Reflect === "object" && typeof Reflect.decorate === "function") r = Reflect.decorate(decorators, target, key, desc);
    else for (var i = decorators.length - 1; i >= 0; i--) if (d = decorators[i]) r = (c < 3 ? d(r) : c > 3 ? d(target, key, r) : d(target, key)) || r;
    return c > 3 && r && Object.defineProperty(target, key, r), r;
};
var __metadata = (this && this.__metadata) || function (k, v) {
    if (typeof Reflect === "object" && typeof Reflect.metadata === "function") return Reflect.metadata(k, v);
};
var __param = (this && this.__param) || function (paramIndex, decorator) {
    return function (target, key) { decorator(target, key, paramIndex); }
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.AdminController = void 0;
const common_1 = require("@nestjs/common");
const node_crypto_1 = require("node:crypto");
const admin_excel_1 = require("./admin-excel");
const admin_print_1 = require("./admin-print");
const admin_service_1 = require("./admin.service");
const admin_view_1 = require("./admin-view");
let AdminController = class AdminController {
    adminService;
    constructor(adminService) {
        this.adminService = adminService;
    }
    async dashboard(noticeText) {
        const data = await this.adminService.dashboard();
        const cards = [
            ['/admin/companies', 'شرکت‌ها', data.companies],
            ['/admin/bank-accounts', 'حساب‌های بانکی', data.bankAccounts],
            ['/admin/cheques', 'چک‌ها', data.cheques],
            ['/admin/cash-payments', 'واریزی‌ها', data.cashPayments],
            ['/admin/users', 'کاربران', data.users],
            ['/admin/orders', 'کل سفارشات', data.orders],
            ['/admin/orders?status=PENDING', 'در انتظار سفارش', data.pendingOrders],
            ['/admin/catalog', 'دارو و کالا', data.catalogItems],
            ['/admin/audit-logs', 'رویدادهای تغییرات', data.auditLogs],
        ]
            .map(([href, label, value]) => `
          <a class="card" href="${href}">
            <div class="muted">${label}</div>
            <div class="metric">${(0, admin_view_1.formatAmount)(value)}</div>
          </a>`)
            .join('');
        return (0, admin_view_1.layout)('داشبورد مدیریتی', `${(0, admin_view_1.notice)(noticeText)}
       <div class="page-title"><h1>داشبورد کامل مدیریتی</h1></div>
       <div class="cards">${cards}</div>`, 'dashboard');
    }
    release() {
        return {
            release: admin_view_1.ADMIN_DASHBOARD_RELEASE,
            sections: [
                'invoices',
                'companies',
                'bank-accounts',
                'cheques',
                'cash-payments',
                'users',
                'orders',
                'catalog',
                'audit-logs',
            ],
            hardDelete: true,
        };
    }
    async catalog(q = '', category = '', active = '', shape = '', sort = 'SYNC_DESC', page = '1', pageSize = '50', noticeText) {
        const data = await this.adminService.catalog({
            q,
            category,
            active,
            shape,
            sort,
            page,
            pageSize,
        });
        const categoryOptions = [
            this.option('', 'همه اقلام', category),
            this.option('DRUG', 'دارو', category),
            this.option('GOODS', 'کالا', category),
        ].join('');
        const activeOptions = [
            this.option('', 'همه وضعیت‌ها', active),
            this.option('ACTIVE', 'فعال', active),
            this.option('INACTIVE', 'غیرفعال', active),
        ].join('');
        const shapeOptions = [
            this.option('', 'همه فرم‌ها', shape),
            ...data.shapes.map((name) => this.option(name, name, shape)),
        ].join('');
        const sortOptions = [
            this.option('SYNC_DESC', 'آخرین تغییر/Sync', data.sort),
            this.option('SYNC_ASC', 'قدیمی‌ترین Sync', data.sort),
            this.option('NAME_ASC', 'نام فارسی: الف تا ی', data.sort),
            this.option('NAME_DESC', 'نام فارسی: ی تا الف', data.sort),
            this.option('ARSEN_ID_DESC', 'شناسه آرسن: جدید به قدیم', data.sort),
            this.option('ARSEN_ID_ASC', 'شناسه آرسن: قدیم به جدید', data.sort),
            this.option('SALES_DESC', 'قیمت فروش: بیشترین', data.sort),
            this.option('SALES_ASC', 'قیمت فروش: کمترین', data.sort),
            this.option('PURCHASE_DESC', 'آخرین قیمت خرید: بیشترین', data.sort),
            this.option('PURCHASE_ASC', 'آخرین قیمت خرید: کمترین', data.sort),
        ].join('');
        const pageSizeOptions = [25, 50, 100, 200]
            .map((size) => this.option(String(size), String(size), String(data.pageSize)))
            .join('');
        const stats = [
            ['کل اقلام', data.stats.totalItems],
            ['دارو', data.stats.drugCount],
            ['کالا', data.stats.goodsCount],
            ['فعال', data.stats.activeCount],
            ['غیرفعال', data.stats.inactiveCount],
        ]
            .map(([label, value]) => `<div class="card catalog-stat">
          <div class="muted">${(0, admin_view_1.escapeHtml)(label)}</div>
          <div class="metric">${(0, admin_view_1.formatAmount)(value)}</div>
        </div>`)
            .join('');
        const rows = data.items
            .map((item) => `<tr>
          <td>${this.catalogCategoryBadge(item.category)}</td>
          <td><strong>${(0, admin_view_1.escapeHtml)(item.persianName || '—')}</strong></td>
          <td>${(0, admin_view_1.escapeHtml)(item.genericName || '—')}</td>
          <td>${(0, admin_view_1.escapeHtml)(item.persianBrandName || '—')}</td>
          <td>${(0, admin_view_1.escapeHtml)(item.brandName || '—')}</td>
          <td>${(0, admin_view_1.escapeHtml)(item.unit || '—')}</td>
          <td>${(0, admin_view_1.escapeHtml)(item.shapeName || '—')}</td>
          <td>${item.packetQuantity == null ? '—' : (0, admin_view_1.formatAmount)(item.packetQuantity)}</td>
          <td>${this.amountOrDash(item.salesPrice)}</td>
          <td>${this.amountOrDash(item.lastPurchasePrice)}</td>
          <td>${(0, admin_view_1.statusBadge)(item.isActive ? 'ACTIVE' : 'INACTIVE')}</td>
          <td>${(0, admin_view_1.formatDate)(item.sourceSyncedAt)}</td>
          <td><a class="button secondary" href="/admin/catalog/${item.id}">جزئیات</a></td>
        </tr>`)
            .join('');
        const pageUrl = (targetPage) => this.catalogListUrl({
            q,
            category,
            active,
            shape,
            sort: data.sort,
            page: String(targetPage),
            pageSize: String(data.pageSize),
        });
        const pageWindow = (0, admin_view_1.invoicePaginationWindow)(data.page, data.totalPages, 10);
        const pageNumberLinks = pageWindow.pages
            .map((pageNumber) => pageNumber === data.page
            ? `<span class="page-link active" aria-current="page">${(0, admin_view_1.formatAmount)(pageNumber)}</span>`
            : `<a class="page-link" href="${(0, admin_view_1.escapeHtml)(pageUrl(pageNumber))}">${(0, admin_view_1.formatAmount)(pageNumber)}</a>`)
            .join('');
        const firstDisabled = data.page <= 1;
        const lastDisabled = data.page >= data.totalPages;
        const firstLink = firstDisabled
            ? '<span class="page-link disabled" aria-disabled="true">&lt;&lt;</span>'
            : `<a class="page-link" href="${(0, admin_view_1.escapeHtml)(pageUrl(1))}">&lt;&lt;</a>`;
        const previousLink = firstDisabled
            ? '<span class="page-link disabled" aria-disabled="true">&lt;</span>'
            : `<a class="page-link" href="${(0, admin_view_1.escapeHtml)(pageUrl(data.page - 1))}">&lt;</a>`;
        const nextLink = lastDisabled
            ? '<span class="page-link disabled" aria-disabled="true">&gt;</span>'
            : `<a class="page-link" href="${(0, admin_view_1.escapeHtml)(pageUrl(data.page + 1))}">&gt;</a>`;
        const lastLink = lastDisabled
            ? '<span class="page-link disabled" aria-disabled="true">&gt;&gt;</span>'
            : `<a class="page-link" href="${(0, admin_view_1.escapeHtml)(pageUrl(data.totalPages))}">&gt;&gt;</a>`;
        const pagination = data.totalPages > 1
            ? `<div class="pagination">
             ${firstLink}
             ${previousLink}
             ${pageWindow.showLeadingEllipsis ? '<span class="ellipsis">…</span>' : ''}
             ${pageNumberLinks}
             ${pageWindow.showTrailingEllipsis ? '<span class="ellipsis">…</span>' : ''}
             ${nextLink}
             ${lastLink}
           </div>`
            : '';
        const listStateActive = Boolean(q ||
            category ||
            active ||
            shape ||
            data.sort !== 'SYNC_DESC' ||
            data.page !== 1 ||
            data.pageSize !== 50);
        return (0, admin_view_1.layout)('دارو و کالا', `<div class="page-title">
         <h1>دارو و کالا</h1>
         <span class="badge">فقط خواندنی از آرسن</span>
       </div>
       <div class="cards catalog-stats">${stats}</div>
       <form class="filters catalog-filters" method="get" action="/admin/catalog" id="catalog-filter-form">
         <div class="field search-field"><label>جستجو</label><input name="q" id="catalog-live-search" value="${(0, admin_view_1.escapeHtml)(q)}" placeholder="نام فارسی، ژنریک، برند یا شناسه آرسن" autocomplete="off"><span class="muted catalog-live-status" id="catalog-live-status" aria-live="polite"></span></div>
         <div class="field"><label>نوع</label><select name="category">${categoryOptions}</select></div>
         <div class="field"><label>وضعیت</label><select name="active">${activeOptions}</select></div>
         <div class="field"><label>فرم</label><select name="shape">${shapeOptions}</select></div>
         <div class="field sort-field"><label>مرتب‌سازی</label><select name="sort">${sortOptions}</select></div>
         <div class="field page-size"><label>تعداد نمایش</label><select name="pageSize">${pageSizeOptions}</select></div>
         <button type="submit">اعمال</button>
         <button type="submit" class="button secondary" formaction="/admin/catalog/export" title="خروجی همه نتایج فعلی، نه فقط صفحه جاری">خروجی اکسل</button>
         <button type="submit" class="button secondary" formaction="/admin/catalog/pdf" formtarget="_blank" title="نسخه چاپی همه نتایج فعلی برای ذخیره به‌صورت PDF">خروجی PDF</button>
         <a id="catalog-clear-link" class="button secondary" href="/admin/catalog"${listStateActive ? '' : ' hidden'}>پاک کردن</a>
       </form>
       <div id="catalog-results">
         <div class="table-meta">
           <span class="muted">نتیجه فیلتر: ${(0, admin_view_1.formatAmount)(data.totalCount)} قلم — ${(0, admin_view_1.formatAmount)(data.pageSize)} ردیف در هر صفحه</span>
         </div>
         <div class="table-wrap catalog-table"><table><thead><tr>
           ${['نوع', 'نام فارسی', 'نام ژنریک', 'برند فارسی', 'برند انگلیسی', 'واحد/دوز', 'فرم', 'تعداد در بسته', 'قیمت فروش', 'آخرین قیمت خرید', 'وضعیت', 'آخرین Sync', 'عملیات'].map((header) => `<th>${(0, admin_view_1.escapeHtml)(header)}</th>`).join('')}
         </tr></thead><tbody>
           ${rows || '<tr><td colspan="13">قلمی با این فیلترها پیدا نشد.</td></tr>'}
         </tbody></table></div>
         ${pagination}
         <div class="pagination-summary"><span class="muted">صفحه ${(0, admin_view_1.formatAmount)(data.page)} از ${(0, admin_view_1.formatAmount)(data.totalPages)}</span></div>
       </div>
       <script>
       (() => {
         const form = document.getElementById('catalog-filter-form');
         const input = document.getElementById('catalog-live-search');
         const results = document.getElementById('catalog-results');
         const status = document.getElementById('catalog-live-status');
         const clearLink = document.getElementById('catalog-clear-link');
         if (!form || !input || !results) return;

         let timer = 0;
         let requestController = null;
         let requestSerial = 0;

         const hasActiveFilter = () => {
           const data = new FormData(form);
           for (const [key, value] of data.entries()) {
             const text = String(value || '').trim();
             if (!text) continue;
             if (key === 'sort' && text === 'SYNC_DESC') continue;
             if (key === 'pageSize' && text === '50') continue;
             return true;
           }
           return false;
         };

         const updateClearLink = () => {
           if (clearLink) clearLink.hidden = !hasActiveFilter();
         };

         const buildUrl = () => {
           const data = new FormData(form);
           const params = new URLSearchParams();
           for (const [key, value] of data.entries()) {
             const text = String(value || '').trim();
             if (text) params.set(key, text);
           }
           params.delete('page');
           const query = params.toString();
           return '/admin/catalog' + (query ? '?' + query : '');
         };

         const liveSearch = async () => {
           const serial = ++requestSerial;
           const url = buildUrl();

           if (requestController) requestController.abort();
           requestController = new AbortController();

           if (status) status.textContent = 'در حال جستجو…';
           results.setAttribute('aria-busy', 'true');
           updateClearLink();

           try {
             const response = await fetch(url, {
               method: 'GET',
               credentials: 'same-origin',
               signal: requestController.signal,
               headers: { 'X-Requested-With': 'PharmaFlow-Catalog-Live-Search' },
             });

             if (!response.ok) throw new Error('HTTP ' + response.status);

             const html = await response.text();
             if (serial !== requestSerial) return;

             const doc = new DOMParser().parseFromString(html, 'text/html');
             const nextResults = doc.getElementById('catalog-results');
             if (!nextResults) throw new Error('Catalog results were not found.');

             results.innerHTML = nextResults.innerHTML;
             history.replaceState(null, '', url);
             if (status) status.textContent = '';
           } catch (error) {
             if (error && error.name === 'AbortError') return;
             if (status) status.textContent = 'خطا در جستجوی زنده؛ Enter یا دکمه اعمال را بزنید.';
           } finally {
             if (serial === requestSerial) results.removeAttribute('aria-busy');
           }
         };

         input.addEventListener('input', () => {
           window.clearTimeout(timer);
           updateClearLink();
           timer = window.setTimeout(liveSearch, 300);
         });

         updateClearLink();
       })();
       </script>`, 'catalog');
    }
    async exportCatalog(q = '', category = '', active = '', shape = '', sort = 'SYNC_DESC', response) {
        const items = await this.adminService.catalogExport({
            q,
            category,
            active,
            shape,
            sort,
        });
        const file = (0, admin_excel_1.buildXlsx)('دارو و کالا', [
            'شناسه آرسن',
            'نوع',
            'نام فارسی',
            'نام ژنریک',
            'برند فارسی',
            'برند انگلیسی',
            'واحد / دوز',
            'فرم',
            'تعداد در بسته',
            'قیمت فروش',
            'آخرین قیمت خرید',
            'وضعیت',
            'توضیحات',
            'آخرین Sync',
        ], items.map((item) => [
            String(item.arsenDrugId),
            item.category === 'DRUG' ? 'دارو' : item.category === 'GOODS' ? 'کالا' : item.category,
            item.persianName ?? '',
            item.genericName ?? '',
            item.persianBrandName ?? '',
            item.brandName ?? '',
            item.unit ?? '',
            item.shapeName ?? '',
            item.packetQuantity ?? '',
            this.excelNumber(item.salesPrice),
            this.excelNumber(item.lastPurchasePrice),
            item.isActive ? 'فعال' : 'غیرفعال',
            item.description ?? '',
            this.excelDateTime(item.sourceSyncedAt),
        ]));
        return this.sendXlsx(response, 'pharmaflow-catalog', file);
    }
    async exportCatalogPdf(q = '', category = '', active = '', shape = '', sort = 'SYNC_DESC') {
        const items = await this.adminService.catalogExport({
            q,
            category,
            active,
            shape,
            sort,
        });
        return (0, admin_print_1.buildPrintToPdfReport)('دارو و کالا', [
            'شناسه آرسن',
            'نوع',
            'نام فارسی',
            'نام ژنریک',
            'برند فارسی',
            'برند انگلیسی',
            'واحد / دوز',
            'فرم',
            'تعداد در بسته',
            'قیمت فروش',
            'آخرین قیمت خرید',
            'وضعیت',
        ], items.map((item) => [
            String(item.arsenDrugId),
            item.category === 'DRUG'
                ? 'دارو'
                : item.category === 'GOODS'
                    ? 'کالا'
                    : item.category,
            item.persianName ?? '',
            item.genericName ?? '',
            item.persianBrandName ?? '',
            item.brandName ?? '',
            item.unit ?? '',
            item.shapeName ?? '',
            item.packetQuantity ?? '',
            item.salesPrice == null ? '' : (0, admin_view_1.formatAmount)(item.salesPrice),
            item.lastPurchasePrice == null
                ? ''
                : (0, admin_view_1.formatAmount)(item.lastPurchasePrice),
            item.isActive ? 'فعال' : 'غیرفعال',
        ]), 'همه رکوردهای منطبق با فیلترهای فعلی - بدون محدودیت صفحه‌بندی');
    }
    async catalogItem(id) {
        const item = await this.adminService.catalogItem(id);
        return (0, admin_view_1.layout)(item.persianName || item.genericName || `Arsen ${String(item.arsenDrugId)}`, `<div class="page-title">
         <h1>${(0, admin_view_1.escapeHtml)(item.persianName || item.genericName || 'جزئیات قلم')}</h1>
         ${this.catalogCategoryBadge(item.category)}
         ${(0, admin_view_1.statusBadge)(item.isActive ? 'ACTIVE' : 'INACTIVE')}
         <a class="button secondary" href="/admin/catalog">بازگشت به دارو و کالا</a>
       </div>
       <div class="notice catalog-source-note">این اطلاعات از Master آرسن Sync می‌شود و در داشبورد مدیریتی فقط خواندنی است.</div>
       <div class="form-card"><div class="grid">
         <div class="field"><label>نام فارسی</label><div>${(0, admin_view_1.escapeHtml)(item.persianName || '—')}</div></div>
         <div class="field"><label>نام ژنریک</label><div>${(0, admin_view_1.escapeHtml)(item.genericName || '—')}</div></div>
         <div class="field"><label>نام برند فارسی</label><div>${(0, admin_view_1.escapeHtml)(item.persianBrandName || '—')}</div></div>
         <div class="field"><label>نام برند انگلیسی</label><div>${(0, admin_view_1.escapeHtml)(item.brandName || '—')}</div></div>
         <div class="field"><label>واحد / دوز</label><div>${(0, admin_view_1.escapeHtml)(item.unit || '—')}</div></div>
         <div class="field"><label>شکل / فرم</label><div>${(0, admin_view_1.escapeHtml)(item.shapeName || '—')}</div></div>
         <div class="field"><label>تعداد در بسته</label><div>${item.packetQuantity == null ? '—' : (0, admin_view_1.formatAmount)(item.packetQuantity)}</div></div>
         <div class="field"><label>قیمت فروش</label><div>${this.amountOrDash(item.salesPrice)}</div></div>
         <div class="field"><label>آخرین قیمت خرید</label><div>${this.amountOrDash(item.lastPurchasePrice)}</div></div>
         <div class="field"><label>وضعیت</label><div>${(0, admin_view_1.statusBadge)(item.isActive ? 'ACTIVE' : 'INACTIVE')}</div></div>
         ${item.description ? `<div class="field full"><label>توضیحات</label><div class="catalog-description">${(0, admin_view_1.escapeHtml)(item.description)}</div></div>` : ''}
         <div class="field full muted system">
           Arsen Drug ID: ${(0, admin_view_1.escapeHtml)(item.arsenDrugId)}<br>
           Category: ${(0, admin_view_1.escapeHtml)(item.category)}<br>
           Imported: ${(0, admin_view_1.formatDate)(item.importedAt)}<br>
           Source synced: ${(0, admin_view_1.formatDate)(item.sourceSyncedAt)}<br>
           UUID: ${(0, admin_view_1.escapeHtml)(item.id)}
         </div>
       </div></div>`, 'catalog');
    }
    async invoices(invoiceNumber = '', companyId = '', docType = '', dateFrom = '', dateTo = '', page = '1', pageSize = '50', noticeText) {
        const data = await this.adminService.invoices({
            invoiceNumber,
            companyId,
            docType,
            dateFrom,
            dateTo,
            page,
            pageSize,
        });
        const companyOptions = [
            this.option('', 'همه شرکت‌ها', companyId),
            ...data.companies.map((company) => this.option(company.id, company.name, companyId)),
        ].join('');
        const docTypeOptions = [
            this.option('', 'خرید و برگشت خرید', docType),
            this.option('1', 'خرید', docType),
            this.option('2', 'برگشت خرید', docType),
        ].join('');
        const pageSizeOptions = [25, 50, 100, 200]
            .map((size) => this.option(String(size), String(size), String(data.pageSize)))
            .join('');
        const rows = data.items
            .map((item) => `<tr class="invoice-row payment-${item.paymentStatus.toLowerCase()}" data-company-id="${(0, admin_view_1.escapeHtml)(item.company.id)}" data-company-name="${(0, admin_view_1.escapeHtml)(item.company.name)}" data-remaining="${item.remainingAmount}" data-selectable="${item.factorDocType === 1 && !item.isDeletedInArsen && item.paymentStatus !== 'PAID' ? '1' : '0'}">
          <td><input class="invoice-select" type="checkbox" value="${(0, admin_view_1.escapeHtml)(item.id)}" ${item.factorDocType !== 1 || item.isDeletedInArsen || item.paymentStatus === 'PAID' ? 'disabled' : ''}></td>
          <td>${(0, admin_view_1.escapeHtml)(item.invoiceDate || '—')}</td>
          <td><strong>${(0, admin_view_1.escapeHtml)(item.invoiceNumber || '—')}</strong></td>
          <td>${(0, admin_view_1.escapeHtml)(item.company.name)}</td>
          <td>${(0, admin_view_1.escapeHtml)(this.invoiceDocTypeLabel(item.factorDocType, item.factorDocTypeName))}</td>
          <td>${this.amountOrDash(item.factorPayablePrice)}</td>
          <td>${(0, admin_view_1.escapeHtml)(item.settlementDate || '—')}</td>
          <td>${(0, admin_view_1.formatAmount)(item.itemCount)}</td>
          <td>${(0, admin_view_1.formatDate)(item.importedAt)}</td>
          <td>${item.isDeletedInArsen ? (0, admin_view_1.statusBadge)('DELETED') : (0, admin_view_1.statusBadge)('ACTIVE')}</td>
          <td>${item.paymentStatus === 'PAID' ? '<span class="badge ok">✓ پرداخت‌شده</span>' : item.paymentStatus === 'PARTIAL' ? `<span class="badge warn">پرداخت بخشی — ${(0, admin_view_1.formatAmount)(item.remainingAmount)} ریال مانده</span>` : '<span class="badge">پرداخت‌نشده</span>'}</td>
          <td><a class="button secondary" href="/admin/invoices/${item.id}">جزئیات</a></td>
        </tr>`)
            .join('');
        const pageUrl = (targetPage) => this.invoiceListUrl({
            invoiceNumber,
            companyId,
            docType,
            dateFrom,
            dateTo,
            page: String(targetPage),
            pageSize: String(data.pageSize),
        });
        const pageWindow = (0, admin_view_1.invoicePaginationWindow)(data.page, data.totalPages, 10);
        const pageNumberLinks = pageWindow.pages
            .map((pageNumber) => pageNumber === data.page
            ? `<span class="page-link active" aria-current="page">${(0, admin_view_1.formatAmount)(pageNumber)}</span>`
            : `<a class="page-link" href="${(0, admin_view_1.escapeHtml)(pageUrl(pageNumber))}">${(0, admin_view_1.formatAmount)(pageNumber)}</a>`)
            .join('');
        const firstDisabled = data.page <= 1;
        const lastDisabled = data.page >= data.totalPages;
        const firstLink = firstDisabled
            ? '<span class="page-link disabled" aria-disabled="true">&lt;&lt;</span>'
            : `<a class="page-link" href="${(0, admin_view_1.escapeHtml)(pageUrl(1))}">&lt;&lt;</a>`;
        const previousLink = firstDisabled
            ? '<span class="page-link disabled" aria-disabled="true">&lt;</span>'
            : `<a class="page-link" href="${(0, admin_view_1.escapeHtml)(pageUrl(data.page - 1))}">&lt;</a>`;
        const nextLink = lastDisabled
            ? '<span class="page-link disabled" aria-disabled="true">&gt;</span>'
            : `<a class="page-link" href="${(0, admin_view_1.escapeHtml)(pageUrl(data.page + 1))}">&gt;</a>`;
        const lastLink = lastDisabled
            ? '<span class="page-link disabled" aria-disabled="true">&gt;&gt;</span>'
            : `<a class="page-link" href="${(0, admin_view_1.escapeHtml)(pageUrl(data.totalPages))}">&gt;&gt;</a>`;
        const pagination = data.totalPages > 1
            ? `<div class="pagination">
             ${firstLink}
             ${previousLink}
             ${pageWindow.showLeadingEllipsis ? '<span class="ellipsis">…</span>' : ''}
             ${pageNumberLinks}
             ${pageWindow.showTrailingEllipsis ? '<span class="ellipsis">…</span>' : ''}
             ${nextLink}
             ${lastLink}
           </div>`
            : '';
        const filtersActive = Boolean(invoiceNumber || companyId || docType || dateFrom || dateTo);
        const listStateActive = filtersActive || data.page !== 1 || data.pageSize !== 50;
        return (0, admin_view_1.layout)('فاکتورها', `${(0, admin_view_1.notice)(noticeText)}<div class="page-title"><h1>فاکتورها</h1></div>
       <form class="filters invoice-filters" method="get" action="/admin/invoices" id="invoice-filter-form">
         <div class="field"><label>شماره فاکتور</label><input name="invoiceNumber" id="invoice-live-search" value="${(0, admin_view_1.escapeHtml)(invoiceNumber)}" placeholder="بخشی از شماره فاکتور" autocomplete="off"><span class="muted catalog-live-status" id="invoice-live-status" aria-live="polite"></span></div>
         <div class="field company"><label>شرکت</label><select name="companyId">${companyOptions}</select></div>
         <div class="field"><label>نوع فاکتور</label><select name="docType">${docTypeOptions}</select></div>
         <div class="field"><label>از تاریخ فاکتور</label><input name="dateFrom" value="${(0, admin_view_1.escapeHtml)(dateFrom)}" placeholder="1405/01/01" inputmode="numeric"></div>
         <div class="field"><label>تا تاریخ فاکتور</label><input name="dateTo" value="${(0, admin_view_1.escapeHtml)(dateTo)}" placeholder="1405/12/29" inputmode="numeric"></div>
         <div class="field page-size"><label>تعداد نمایش</label><select name="pageSize">${pageSizeOptions}</select></div>
         <button type="submit">اعمال فیلتر</button>
         <button type="submit" class="button secondary" formaction="/admin/invoices/export" title="خروجی همه نتایج فعلی، نه فقط صفحه جاری">خروجی اکسل</button>
         <button type="submit" class="button secondary" formaction="/admin/invoices/pdf" formtarget="_blank" title="نسخه چاپی همه نتایج فعلی برای ذخیره به‌صورت PDF">خروجی PDF</button>
         <a id="invoice-clear-link" class="button secondary" href="/admin/invoices"${listStateActive ? '' : ' hidden'}>پاک کردن</a>
       </form>
       <div id="invoice-results">
         <div class="invoice-selection-bar" id="invoice-selection-bar" hidden><strong><span id="invoice-selection-count">۰</span> فاکتور از <span id="invoice-selection-company"></span></strong><span>جمع مانده انتخاب‌شده: <strong id="invoice-selection-total">۰</strong> ریال</span><button type="button" id="invoice-cheque-action">صدور چک</button><button type="button" class="button secondary" id="invoice-cash-action">پرداخت نقدی</button></div>
         <div class="table-meta">
           <span class="muted">نمایش ${(0, admin_view_1.formatAmount)(data.pageSize)} فاکتور در هر صفحه — مجموع ${(0, admin_view_1.formatAmount)(data.totalCount)} فاکتور — مرتب‌شده بر اساس آخرین ورود به PharmaFlow</span>
         </div>
         <div class="table-wrap"><table><thead><tr>
           ${['انتخاب', 'تاریخ فاکتور', 'شماره فاکتور', 'شرکت', 'نوع', 'مبلغ قابل پرداخت', 'تاریخ تسویه', 'اقلام', 'ورود به PharmaFlow', 'وضعیت منبع', 'وضعیت پرداخت', 'عملیات'].map((header) => `<th>${(0, admin_view_1.escapeHtml)(header)}</th>`).join('')}
         </tr></thead><tbody>
           ${rows || '<tr><td colspan="12">فاکتوری با این فیلترها یافت نشد.</td></tr>'}
         </tbody></table></div>
         ${pagination}
         <div class="pagination-summary"><span class="muted">صفحه ${(0, admin_view_1.formatAmount)(data.page)} از ${(0, admin_view_1.formatAmount)(data.totalPages)}</span></div>
       </div>
       <script>
       (() => {
         const form = document.getElementById('invoice-filter-form');
         const input = document.getElementById('invoice-live-search');
         const results = document.getElementById('invoice-results');
         const status = document.getElementById('invoice-live-status');
         const clearLink = document.getElementById('invoice-clear-link');
         if (!form || !input || !results) return;
         let timer = 0, requestController = null, requestSerial = 0;
         const refreshSelection = () => {
           const selected = Array.from(results.querySelectorAll('.invoice-select:checked')), bar = document.getElementById('invoice-selection-bar'); if (!bar) return;
           if (!selected.length) { bar.hidden = true; results.querySelectorAll('.invoice-select').forEach((box) => { box.disabled = box.closest('tr').dataset.selectable !== '1'; }); return; }
           const companyId = selected[0].closest('tr').dataset.companyId;
           results.querySelectorAll('.invoice-select:not(:checked)').forEach((box) => { box.disabled = box.closest('tr').dataset.companyId !== companyId || box.closest('tr').dataset.selectable !== '1'; });
           const total = selected.reduce((sum, box) => sum + Number(box.closest('tr').dataset.remaining || 0), 0);
           document.getElementById('invoice-selection-count').textContent = new Intl.NumberFormat('fa-IR').format(selected.length); document.getElementById('invoice-selection-company').textContent = selected[0].closest('tr').dataset.companyName; document.getElementById('invoice-selection-total').textContent = new Intl.NumberFormat('fa-IR').format(total); bar.hidden = false;
         };
         const openSettlement = (kind) => { const ids = Array.from(results.querySelectorAll('.invoice-select:checked')).map((box) => box.value); if (ids.length) location.href = '/admin/invoices/settlement/new?kind=' + kind + '&invoiceIds=' + encodeURIComponent(ids.join(',')); };
         results.addEventListener('change', (event) => { if (event.target.classList.contains('invoice-select')) refreshSelection(); });
         results.addEventListener('click', (event) => { if (event.target.id === 'invoice-cheque-action') openSettlement('CHEQUE'); if (event.target.id === 'invoice-cash-action') openSettlement('CASH'); });

         const hasActiveFilter = () => {
           const data = new FormData(form);
           for (const [key, value] of data.entries()) {
             const text = String(value || '').trim();
             if (!text) continue;
             if (key === 'pageSize' && text === '50') continue;
             return true;
           }
           return false;
         };
         const updateClearLink = () => { if (clearLink) clearLink.hidden = !hasActiveFilter(); };
         const buildUrl = () => {
           const data = new FormData(form), params = new URLSearchParams();
           for (const [key, value] of data.entries()) {
             const text = String(value || '').trim();
             if (text) params.set(key, text);
           }
           params.delete('page');
           const query = params.toString();
           return '/admin/invoices' + (query ? '?' + query : '');
         };
         const liveSearch = async () => {
           const serial = ++requestSerial, url = buildUrl();
           if (requestController) requestController.abort();
           requestController = new AbortController();
           if (status) status.textContent = 'در حال جستجو…';
           results.setAttribute('aria-busy', 'true');
           updateClearLink();
           try {
             const response = await fetch(url, {
               method: 'GET', credentials: 'same-origin', signal: requestController.signal,
               headers: { 'X-Requested-With': 'PharmaFlow-Invoice-Live-Search' },
             });
             if (!response.ok) throw new Error('HTTP ' + response.status);
             const html = await response.text();
             if (serial !== requestSerial) return;
             const doc = new DOMParser().parseFromString(html, 'text/html');
             const nextResults = doc.getElementById('invoice-results');
             if (!nextResults) throw new Error('Invoice results were not found.');
             results.innerHTML = nextResults.innerHTML;
             refreshSelection();
             history.replaceState(null, '', url);
             if (status) status.textContent = '';
           } catch (error) {
             if (error && error.name === 'AbortError') return;
             if (status) status.textContent = 'خطا در جستجوی زنده؛ Enter یا دکمه اعمال فیلتر را بزنید.';
           } finally {
             if (serial === requestSerial) results.removeAttribute('aria-busy');
           }
         };
         input.addEventListener('input', () => {
           window.clearTimeout(timer);
           updateClearLink();
           timer = window.setTimeout(liveSearch, 300);
         });
         updateClearLink();
       })();
       </script>`, 'invoices');
    }
    async newInvoiceSettlement(kind = '', invoiceIds = '') {
        if (kind !== 'CHEQUE' && kind !== 'CASH')
            throw new common_1.ForbiddenException('Invalid settlement type.');
        const data = await this.adminService.invoiceSettlementForm(invoiceIds);
        const accountOptions = data.bankAccounts.map((account) => this.option(account.id, account.accountTitle || account.bankName, '')).join('');
        const rows = data.invoices.map((invoice) => `<tr><td>${(0, admin_view_1.escapeHtml)(invoice.invoiceNumber || '—')}</td><td>${(0, admin_view_1.escapeHtml)(invoice.invoiceDate || '—')}</td><td>${(0, admin_view_1.formatAmount)(invoice.remainingAmount)} ریال</td></tr>`).join('');
        const today = new Date().toISOString().slice(0, 10);
        const methods = this.option('BANK_DEPOSIT', 'واریز بانکی', 'BANK_DEPOSIT') + this.option('POS_PAYMENT', 'پرداخت کارتخوان', 'BANK_DEPOSIT');
        const specific = kind === 'CHEQUE' ? `${this.field('شماره چک', 'chequeNumber', '')}${this.field('تاریخ سررسید', 'dueDate', '', 'date')}` : `${this.selectField('روش پرداخت', 'paymentMethod', methods)}${this.field('شماره پیگیری', 'trackingNumber', '')}`;
        return (0, admin_view_1.layout)(kind === 'CHEQUE' ? 'صدور چک برای فاکتورها' : 'پرداخت نقدی فاکتورها', `<div class="page-title"><h1>${kind === 'CHEQUE' ? 'صدور چک' : 'پرداخت نقدی'} برای ${(0, admin_view_1.escapeHtml)(data.company.name)}</h1></div><div class="settlement-summary"><strong>مبلغ کل: ${(0, admin_view_1.formatAmount)(data.total)} ریال</strong><div class="table-wrap"><table><thead><tr><th>فاکتور</th><th>تاریخ</th><th>مانده</th></tr></thead><tbody>${rows}</tbody></table></div></div><form class="form-card" method="post" action="/admin/invoices/settlement">${this.csrfInput()}<input type="hidden" name="kind" value="${kind}"><input type="hidden" name="invoiceIds" value="${(0, admin_view_1.escapeHtml)(data.invoiceIds)}"><div class="grid">${this.field('مبلغ (ریال)', 'displayAmount', data.total, 'number').replace('<input ', '<input readonly ')}${this.field(kind === 'CHEQUE' ? 'تاریخ صدور' : 'تاریخ پرداخت', 'paymentDate', today, 'date')}${this.selectField('حساب بانکی', 'bankAccountId', accountOptions)}${specific}${this.textarea('توضیحات', 'description', '')}</div><div class="actions"><button type="submit">ثبت و پرداخت فاکتورها</button><a class="button secondary" href="/admin/invoices">انصراف</a></div></form>`, 'invoices');
    }
    async createInvoiceSettlement(body, response) {
        this.verifyCsrf(body._csrf);
        const kind = body.kind === 'CHEQUE' ? 'CHEQUE' : body.kind === 'CASH' ? 'CASH' : null;
        if (!kind)
            throw new common_1.ForbiddenException('Invalid settlement type.');
        await this.adminService.settleInvoices(kind, body);
        return response.redirect(303, this.withNotice('/admin/invoices', 'پرداخت ثبت شد و وضعیت فاکتورها به‌روزرسانی شد.'));
    }
    async exportInvoices(invoiceNumber = '', companyId = '', docType = '', dateFrom = '', dateTo = '', response) {
        const items = await this.adminService.invoicesExport({
            invoiceNumber,
            companyId,
            docType,
            dateFrom,
            dateTo,
        });
        const file = (0, admin_excel_1.buildXlsx)('فاکتورها', [
            'شناسه فاکتور آرسن',
            'شماره فاکتور',
            'تاریخ فاکتور',
            'شرکت',
            'نوع',
            'مبلغ قابل پرداخت',
            'تاریخ تسویه',
            'مهلت پرداخت (روز)',
            'تعداد اقلام',
            'وضعیت منبع',
            'توضیحات',
            'ورود به PharmaFlow',
            'آخرین Sync',
        ], items.map((item) => [
            item.arsenFactorId,
            item.invoiceNumber ?? '',
            item.invoiceDate ?? '',
            item.company.name,
            this.invoiceDocTypeLabel(item.factorDocType, item.factorDocTypeName),
            this.excelNumber(item.factorPayablePrice),
            item.settlementDate ?? '',
            item.paymentDays ?? '',
            item.itemCount,
            item.isDeletedInArsen ? 'حذف‌شده در آرسن' : 'فعال',
            item.description ?? '',
            this.excelDateTime(item.importedAt),
            this.excelDateTime(item.sourceSyncedAt),
        ]));
        return this.sendXlsx(response, 'pharmaflow-invoices', file);
    }
    async exportInvoicesPdf(invoiceNumber = '', companyId = '', docType = '', dateFrom = '', dateTo = '') {
        const items = await this.adminService.invoicesExport({
            invoiceNumber,
            companyId,
            docType,
            dateFrom,
            dateTo,
        });
        return (0, admin_print_1.buildPrintToPdfReport)('فاکتورها', [
            'تاریخ فاکتور',
            'شماره فاکتور',
            'شرکت',
            'نوع',
            'مبلغ قابل پرداخت',
            'تاریخ تسویه',
            'مهلت پرداخت',
            'تعداد اقلام',
            'وضعیت منبع',
            'توضیحات',
        ], items.map((item) => [
            item.invoiceDate ?? '',
            item.invoiceNumber ?? '',
            item.company.name,
            this.invoiceDocTypeLabel(item.factorDocType, item.factorDocTypeName),
            item.factorPayablePrice == null
                ? ''
                : (0, admin_view_1.formatAmount)(item.factorPayablePrice),
            item.settlementDate ?? '',
            item.paymentDays == null ? '' : `${item.paymentDays} روز`,
            item.itemCount,
            item.isDeletedInArsen ? 'حذف‌شده در آرسن' : 'فعال',
            item.description ?? '',
        ]), 'همه فاکتورهای منطبق با فیلترهای فعلی - بدون محدودیت صفحه‌بندی');
    }
    async invoice(id) {
        const item = await this.adminService.invoice(id);
        const grossTotal = item.items.reduce((sum, detail) => {
            const quantity = Number(detail.quantity ?? 0);
            const purchasePrice = Number(detail.purchasePrice ?? 0);
            return sum + quantity * purchasePrice;
        }, 0);
        const discount = Number(item.factorDiscount ?? 0);
        const tax = Number(item.factorTax ?? 0);
        const sourcePayable = item.factorPayablePrice == null
            ? null
            : Number(item.factorPayablePrice);
        const payable = sourcePayable == null ? grossTotal - discount + tax : sourcePayable;
        const description = String(item.description ?? '').trim();
        const itemRows = item.items
            .map((detail, index) => `<tr>
          <td>${(0, admin_view_1.formatAmount)(index + 1)}</td>
          <td><strong>${(0, admin_view_1.escapeHtml)(detail.drugName || `Drug ${String(detail.arsenDrugId ?? '—')}`)}</strong></td>
          <td>${(0, admin_view_1.escapeHtml)(detail.barcode || '—')}</td>
          <td>${this.amountOrDash(detail.quantity)}</td>
          <td>${detail.packetQuantity == null ? '—' : (0, admin_view_1.formatAmount)(detail.packetQuantity)}</td>
          <td>${this.amountOrDash(detail.purchasePrice)}</td>
          <td>${this.amountOrDash(detail.salePrice)}</td>
          <td>${this.amountOrDash(detail.rowDiscount)}</td>
          <td>${this.amountOrDash(detail.hasTax)}</td>
          <td>${(0, admin_view_1.escapeHtml)(detail.batchNumber || '—')}</td>
          <td>${(0, admin_view_1.escapeHtml)(detail.expireDate || '—')}</td>
        </tr>`)
            .join('');
        return (0, admin_view_1.layout)(`فاکتور ${item.invoiceNumber || item.arsenFactorId}`, `<div class="page-title"><h1>جزئیات فاکتور ${(0, admin_view_1.escapeHtml)(item.invoiceNumber || item.arsenFactorId)}</h1><a class="button secondary" href="/admin/invoices">بازگشت به فاکتورها</a></div>
       <div class="form-card"><div class="grid">
         <div class="field"><label>شرکت</label><div>${(0, admin_view_1.escapeHtml)(item.company.name)}</div></div>
         <div class="field"><label>نوع</label><div>${(0, admin_view_1.escapeHtml)(this.invoiceDocTypeLabel(item.factorDocType, item.factorDocTypeName))}</div></div>
         <div class="field"><label>شماره فاکتور</label><div>${(0, admin_view_1.escapeHtml)(item.invoiceNumber || '—')}</div></div>
         <div class="field"><label>تاریخ فاکتور</label><div>${(0, admin_view_1.escapeHtml)(item.invoiceDate || '—')}</div></div>
         <div class="field"><label>تاریخ سند آرسن</label><div>${(0, admin_view_1.escapeHtml)(item.docDate || '—')}</div></div>
         <div class="field"><label>تاریخ تسویه سند</label><div>${(0, admin_view_1.escapeHtml)(item.settlementDate || '—')}</div></div>
         <div class="field"><label>نوع ثبت</label><div>${(0, admin_view_1.escapeHtml)(item.factorTypeName || item.factorType || '—')}</div></div>
         <div class="field"><label>گروه</label><div>${(0, admin_view_1.escapeHtml)(item.factorItemType || '—')}</div></div>
         <div class="field"><label>مهلت پرداخت</label><div>${item.paymentDays == null ? '—' : `${(0, admin_view_1.formatAmount)(item.paymentDays)} روز`}</div></div>
         <div class="field"><label>جمع فاکتور</label><div>${(0, admin_view_1.formatAmount)(grossTotal)}</div></div>
         <div class="field"><label>تخفیف</label><div>${this.amountOrDash(item.factorDiscount)}</div></div>
         <div class="field"><label>مالیات</label><div>${this.amountOrDash(item.factorTax)}</div></div>
         <div class="field"><label>باربری</label><div>${this.amountOrDash(item.barbariPrice)}</div></div>
         <div class="field"><label>مبلغ قابل پرداخت</label><div><strong>${(0, admin_view_1.formatAmount)(payable)}</strong></div></div>
         ${description ? `<div class="field full"><label>توضیحات</label><div>${(0, admin_view_1.escapeHtml)(description)}</div></div>` : ''}
         <div class="field"><label>تعداد اقلام</label><div>${(0, admin_view_1.formatAmount)(item.itemCount)}</div></div>
         <div class="field"><label>وضعیت در آرسن</label><div>${item.isDeletedInArsen ? (0, admin_view_1.statusBadge)('DELETED') : (0, admin_view_1.statusBadge)('ACTIVE')}</div></div>
         <div class="field"><label>آخرین Save آرسن</label><div>${(0, admin_view_1.formatDate)(item.arsenSaveDateTime)}</div></div>
         <div class="field"><label>ورود به PharmaFlow</label><div>${(0, admin_view_1.formatDate)(item.importedAt)}</div></div>
         <div class="field"><label>آخرین Sync منبع</label><div>${(0, admin_view_1.formatDate)(item.sourceSyncedAt)}</div></div>
         <div class="field full muted system">Arsen Factor ID: ${(0, admin_view_1.escapeHtml)(item.arsenFactorId)}<br>Arsen BusinessPartner ID: ${(0, admin_view_1.escapeHtml)(item.arsenBusinessPartnerId)}<br>Source Partner: ${(0, admin_view_1.escapeHtml)(item.arsenBusinessPartnerName)}<br>UUID: ${(0, admin_view_1.escapeHtml)(item.id)}</div>
       </div></div>
       <div class="page-title" style="margin-top:22px"><h2>اقلام فاکتور</h2></div>
       <div class="table-wrap"><table><thead><tr>
         ${['ردیف', 'کالا/دارو', 'بارکد', 'تعداد', 'تعداد در بسته', 'قیمت خرید', 'قیمت فروش', 'تخفیف ردیف', 'مالیات', 'بچ', 'انقضا'].map((header) => `<th>${(0, admin_view_1.escapeHtml)(header)}</th>`).join('')}
       </tr></thead><tbody>${itemRows || '<tr><td colspan="11">اقلام این فاکتور هنوز Sync نشده‌اند.</td></tr>'}</tbody></table></div>`, 'invoices');
    }
    async companies(q = '', noticeText) {
        const items = await this.adminService.companies(q);
        const csrf = this.csrfToken();
        const rows = items
            .map((item) => {
            const blocked = item._count.cheques +
                item._count.cashPayments +
                item._count.arsenCompanyMappings +
                item._count.arsenInvoices >
                0
                ? `دارای ${item._count.cheques} چک، ${item._count.cashPayments} واریزی، ${item._count.arsenCompanyMappings} مپینگ آرسن و ${item._count.arsenInvoices} فاکتور آرسن است`
                : undefined;
            return `<tr>
          <td><strong>${(0, admin_view_1.escapeHtml)(item.name)}</strong></td>
          <td>${(0, admin_view_1.escapeHtml)(item.nationalId || '—')}</td>
          <td>${(0, admin_view_1.escapeHtml)(item.bankName || '—')}</td>
          <td>${(0, admin_view_1.escapeHtml)(item.accountNumber || '—')}</td>
          <td>${(0, admin_view_1.escapeHtml)(item.cardNumber || '—')}</td>
          <td>${(0, admin_view_1.escapeHtml)(item.shebaNumber || '—')}</td>
          <td>${item._count.cheques}</td>
          <td>${item._count.cashPayments}</td>
          <td>${item._count.arsenCompanyMappings}</td>
          <td>${item.deletedAt ? (0, admin_view_1.statusBadge)('DELETED') : item.archivedAt ? (0, admin_view_1.statusBadge)('ARCHIVED') : (0, admin_view_1.statusBadge)('ACTIVE')}</td>
          <td>${(0, admin_view_1.formatDate)(item.updatedAt)}</td>
          <td><div class="row-actions">
            <a class="button secondary" href="/admin/companies/${item.id}/edit">ویرایش</a>
            ${(0, admin_view_1.hardDeleteForm)(`/admin/companies/${item.id}/hard-delete`, csrf, item.name, blocked)}
          </div></td>
        </tr>`;
        })
            .join('');
        const searchActive = Boolean(String(q ?? '').trim());
        return (0, admin_view_1.layout)('شرکت‌ها', `${(0, admin_view_1.notice)(noticeText)}
       <div class="toolbar">
         <div class="page-title"><h1>شرکت‌ها</h1></div>
         <form class="search" method="get" action="/admin/companies" id="company-filter-form">
           <input name="q" id="company-live-search" value="${(0, admin_view_1.escapeHtml)(q)}" placeholder="نام، شناسه، بانک، ویزیتور..." autocomplete="off">
           <span class="muted catalog-live-status" id="company-live-status" aria-live="polite"></span>
           <button type="submit">جستجو</button>
           <button type="submit" class="button secondary" formaction="/admin/companies/export" title="خروجی همه نتایج فعلی">خروجی اکسل</button>
           <button type="submit" class="button secondary" formaction="/admin/companies/pdf" formtarget="_blank" title="نسخه چاپی همه نتایج فعلی برای ذخیره به‌صورت PDF">خروجی PDF</button>
           <a id="company-clear-link" class="button secondary" href="/admin/companies"${searchActive ? '' : ' hidden'}>پاک کردن</a>
         </form>
       </div>
       <div id="company-results">
         <div class="table-wrap"><table><thead><tr>
           ${['نام شرکت', 'شناسه ملی', 'بانک', 'حساب', 'کارت', 'شبا', 'چک', 'واریزی', 'مپینگ آرسن', 'وضعیت', 'آخرین تغییر', 'عملیات'].map((header) => `<th>${(0, admin_view_1.escapeHtml)(header)}</th>`).join('')}
         </tr></thead><tbody>
           ${rows || '<tr><td colspan="12">رکوردی یافت نشد.</td></tr>'}
         </tbody></table></div>
       </div>
       <script>
       (() => {
         const form = document.getElementById('company-filter-form');
         const input = document.getElementById('company-live-search');
         const results = document.getElementById('company-results');
         const status = document.getElementById('company-live-status');
         const clearLink = document.getElementById('company-clear-link');
         if (!form || !input || !results) return;
         let timer = 0, requestController = null, requestSerial = 0;
         const updateClearLink = () => { if (clearLink) clearLink.hidden = !String(input.value || '').trim(); };
         const buildUrl = () => {
           const q = String(input.value || '').trim();
           return '/admin/companies' + (q ? '?q=' + encodeURIComponent(q) : '');
         };
         const liveSearch = async () => {
           const serial = ++requestSerial, url = buildUrl();
           if (requestController) requestController.abort();
           requestController = new AbortController();
           if (status) status.textContent = 'در حال جستجو…';
           results.setAttribute('aria-busy', 'true');
           updateClearLink();
           try {
             const response = await fetch(url, {
               method: 'GET', credentials: 'same-origin', signal: requestController.signal,
               headers: { 'X-Requested-With': 'PharmaFlow-Company-Live-Search' },
             });
             if (!response.ok) throw new Error('HTTP ' + response.status);
             const html = await response.text();
             if (serial !== requestSerial) return;
             const doc = new DOMParser().parseFromString(html, 'text/html');
             const nextResults = doc.getElementById('company-results');
             if (!nextResults) throw new Error('Company results were not found.');
             results.innerHTML = nextResults.innerHTML;
             history.replaceState(null, '', url);
             if (status) status.textContent = '';
           } catch (error) {
             if (error && error.name === 'AbortError') return;
             if (status) status.textContent = 'خطا در جستجوی زنده؛ Enter یا دکمه جستجو را بزنید.';
           } finally {
             if (serial === requestSerial) results.removeAttribute('aria-busy');
           }
         };
         input.addEventListener('input', () => {
           window.clearTimeout(timer);
           updateClearLink();
           timer = window.setTimeout(liveSearch, 300);
         });
         updateClearLink();
       })();
       </script>`, 'companies');
    }
    async exportCompanies(q = '', response) {
        const items = await this.adminService.companies(q);
        const file = (0, admin_excel_1.buildXlsx)('شرکت‌ها', [
            'نام شرکت',
            'شناسه ملی',
            'کد اقتصادی',
            'بانک',
            'شماره حساب',
            'شماره کارت',
            'شبا',
            'نام ویزیتور',
            'موبایل ویزیتور',
            'نام حسابدار',
            'موبایل حسابدار',
            'توضیحات',
            'تعداد چک',
            'تعداد واریزی',
            'مپینگ آرسن',
            'فاکتور آرسن',
            'وضعیت',
            'آخرین تغییر',
        ], items.map((item) => [
            item.name,
            item.nationalId ?? '',
            item.economicCode ?? '',
            item.bankName ?? '',
            item.accountNumber ?? '',
            item.cardNumber ?? '',
            item.shebaNumber ?? '',
            item.visitorName ?? '',
            item.visitorPhone ?? '',
            item.accountantName ?? '',
            item.accountantPhone ?? '',
            item.notes ?? '',
            item._count.cheques,
            item._count.cashPayments,
            item._count.arsenCompanyMappings,
            item._count.arsenInvoices,
            item.deletedAt ? 'حذف‌شده' : item.archivedAt ? 'آرشیوشده' : 'فعال',
            this.excelDateTime(item.updatedAt),
        ]));
        return this.sendXlsx(response, 'pharmaflow-companies', file);
    }
    async exportCompaniesPdf(q = '') {
        const items = await this.adminService.companies(q);
        return (0, admin_print_1.buildPrintToPdfReport)('شرکت‌ها', [
            'نام شرکت',
            'شناسه ملی',
            'بانک',
            'شماره حساب',
            'شماره کارت',
            'شبا',
            'ویزیتور',
            'حسابدار',
            'تعداد چک',
            'تعداد واریزی',
            'فاکتور آرسن',
            'وضعیت',
        ], items.map((item) => [
            item.name,
            item.nationalId ?? '',
            item.bankName ?? '',
            item.accountNumber ?? '',
            item.cardNumber ?? '',
            item.shebaNumber ?? '',
            [item.visitorName, item.visitorPhone].filter(Boolean).join(' - '),
            [item.accountantName, item.accountantPhone].filter(Boolean).join(' - '),
            item._count.cheques,
            item._count.cashPayments,
            item._count.arsenInvoices,
            item.deletedAt ? 'حذف‌شده' : item.archivedAt ? 'آرشیوشده' : 'فعال',
        ]), 'همه شرکت‌های منطبق با جستجوی فعلی');
    }
    async editCompany(id, noticeText) {
        const item = await this.adminService.company(id);
        const blocked = item._count.cheques +
            item._count.cashPayments +
            item._count.arsenCompanyMappings +
            item._count.arsenInvoices >
            0
            ? `ابتدا ${item._count.cheques} چک، ${item._count.cashPayments} واریزی، ${item._count.arsenCompanyMappings} مپینگ آرسن و ${item._count.arsenInvoices} فاکتور آرسن وابسته را حذف کنید.`
            : undefined;
        return (0, admin_view_1.layout)(`ویرایش ${item.name}`, `${(0, admin_view_1.notice)(noticeText)}
       <div class="page-title"><h1>ویرایش شرکت</h1></div>
       <form class="form-card" method="post" action="/admin/companies/${item.id}">
        ${this.csrfInput()}
        <div class="grid">
          ${this.field('نام شرکت', 'name', item.name)}
          ${this.field('شناسه ملی', 'nationalId', item.nationalId)}
          ${this.field('کد اقتصادی', 'economicCode', item.economicCode)}
          ${this.field('نام بانک', 'bankName', item.bankName)}
          ${this.field('شماره حساب', 'accountNumber', item.accountNumber)}
          ${this.field('شماره کارت', 'cardNumber', item.cardNumber)}
          ${this.field('شماره شبا', 'shebaNumber', item.shebaNumber)}
          ${this.field('نام ویزیتور', 'visitorName', item.visitorName)}
          ${this.field('موبایل ویزیتور', 'visitorPhone', item.visitorPhone)}
          ${this.field('نام حسابدار', 'accountantName', item.accountantName)}
          ${this.field('موبایل حسابدار', 'accountantPhone', item.accountantPhone)}
          ${this.textarea('توضیحات', 'notes', item.notes)}
          ${this.recordState(item.archivedAt, item.deletedAt)}
          ${this.systemInfo(item)}
        </div>
        ${this.saveActions('/admin/companies')}
       </form>
       ${this.dangerZone(`/admin/companies/${item.id}/hard-delete`, item.name, blocked)}`, 'companies');
    }
    async updateCompany(id, body, response) {
        this.verifyCsrf(body._csrf);
        await this.adminService.updateCompany(id, body);
        return response.redirect(303, this.withNotice(`/admin/companies/${id}/edit`, 'تغییرات شرکت ذخیره شد.'));
    }
    async hardDeleteCompany(id, body, response) {
        this.verifyHardDelete(body);
        await this.adminService.hardDeleteCompany(id);
        return response.redirect(303, this.withNotice('/admin/companies', 'شرکت به‌صورت دائمی حذف شد.'));
    }
    async bankAccounts(q = '', noticeText) {
        const items = await this.adminService.bankAccounts(q);
        const csrf = this.csrfToken();
        const rows = items
            .map((item) => {
            const blocked = item._count.cheques + item._count.cashPayments > 0
                ? `دارای ${item._count.cheques} چک و ${item._count.cashPayments} واریزی است`
                : undefined;
            return `<tr>
          <td><strong>${(0, admin_view_1.escapeHtml)(item.accountTitle || item.bankName)}</strong></td>
          <td>${(0, admin_view_1.escapeHtml)(item.bankName)}</td>
          <td>${(0, admin_view_1.escapeHtml)(item.accountHolder || '—')}</td>
          <td>${(0, admin_view_1.escapeHtml)(item.accountNumber || '—')}</td>
          <td>${(0, admin_view_1.escapeHtml)(item.cardNumber || '—')}</td>
          <td>${(0, admin_view_1.escapeHtml)(item.shebaNumber || '—')}</td>
          <td>${item._count.cheques}</td><td>${item._count.cashPayments}</td>
          <td>${item.deletedAt ? (0, admin_view_1.statusBadge)('DELETED') : item.archivedAt ? (0, admin_view_1.statusBadge)('ARCHIVED') : (0, admin_view_1.statusBadge)('ACTIVE')}</td>
          <td>${(0, admin_view_1.formatDate)(item.updatedAt)}</td>
          <td><div class="row-actions"><a class="button secondary" href="/admin/bank-accounts/${item.id}/edit">ویرایش</a>${(0, admin_view_1.hardDeleteForm)(`/admin/bank-accounts/${item.id}/hard-delete`, csrf, item.accountTitle || item.bankName, blocked)}</div></td>
        </tr>`;
        })
            .join('');
        return this.listPage('حساب‌های بانکی', 'accounts', q, noticeText, ['عنوان', 'بانک', 'صاحب حساب', 'حساب', 'کارت', 'شبا', 'چک', 'واریزی', 'وضعیت', 'آخرین تغییر', 'عملیات'], rows, 'بانک، شماره حساب، کارت، شبا...');
    }
    async editBankAccount(id, noticeText) {
        const item = await this.adminService.bankAccount(id);
        const label = item.accountTitle || item.bankName;
        const blocked = item._count.cheques + item._count.cashPayments > 0
            ? `ابتدا ${item._count.cheques} چک و ${item._count.cashPayments} واریزی وابسته را حذف دائمی کنید.`
            : undefined;
        return (0, admin_view_1.layout)('ویرایش حساب بانکی', `${(0, admin_view_1.notice)(noticeText)}<div class="page-title"><h1>ویرایش حساب بانکی</h1></div>
       <form class="form-card" method="post" action="/admin/bank-accounts/${item.id}">
        ${this.csrfInput()}<div class="grid">
          ${this.field('نام بانک', 'bankName', item.bankName)}
          ${this.field('عنوان حساب', 'accountTitle', item.accountTitle)}
          ${this.field('صاحب حساب', 'accountHolder', item.accountHolder)}
          ${this.field('شماره حساب', 'accountNumber', item.accountNumber)}
          ${this.field('شماره کارت', 'cardNumber', item.cardNumber)}
          ${this.field('شماره شبا', 'shebaNumber', item.shebaNumber)}
          ${this.textarea('توضیحات', 'notes', item.notes)}
          ${this.recordState(item.archivedAt, item.deletedAt)}
          ${this.systemInfo(item)}
        </div>${this.saveActions('/admin/bank-accounts')}</form>
       ${this.dangerZone(`/admin/bank-accounts/${item.id}/hard-delete`, label, blocked)}`, 'accounts');
    }
    async updateBankAccount(id, body, response) {
        this.verifyCsrf(body._csrf);
        await this.adminService.updateBankAccount(id, body);
        return response.redirect(303, this.withNotice(`/admin/bank-accounts/${id}/edit`, 'تغییرات حساب ذخیره شد.'));
    }
    async hardDeleteBankAccount(id, body, response) {
        this.verifyHardDelete(body);
        await this.adminService.hardDeleteBankAccount(id);
        return response.redirect(303, this.withNotice('/admin/bank-accounts', 'حساب بانکی به‌صورت دائمی حذف شد.'));
    }
    async cheques(q = '', noticeText) {
        const items = await this.adminService.cheques(q);
        const csrf = this.csrfToken();
        const rows = items
            .map((item) => `<tr>
          <td><strong>${(0, admin_view_1.escapeHtml)(item.chequeNumber)}</strong></td>
          <td>${(0, admin_view_1.escapeHtml)(item.company.name)}</td>
          <td>${(0, admin_view_1.escapeHtml)(item.bankAccount.accountTitle || item.bankAccount.bankName)}</td>
          <td>${(0, admin_view_1.formatAmount)(item.amount)} ریال</td>
          <td>${(0, admin_view_1.formatDate)(item.dueDate)}</td>
          <td>${(0, admin_view_1.statusBadge)(item.status)}</td>
          <td>${item.isRegisteredInSayad ? '<span class="badge ok">ثبت‌شده</span>' : '<span class="badge warn">ثبت‌نشده</span>'}</td>
          <td>${item._count.attachments}</td>
          <td>${item.deletedAt ? (0, admin_view_1.statusBadge)('DELETED') : item.archivedAt ? (0, admin_view_1.statusBadge)('ARCHIVED') : (0, admin_view_1.statusBadge)('ACTIVE')}</td>
          <td><div class="row-actions"><a class="button secondary" href="/admin/cheques/${item.id}/edit">ویرایش</a>${(0, admin_view_1.hardDeleteForm)(`/admin/cheques/${item.id}/hard-delete`, csrf, `چک ${item.chequeNumber}`)}</div></td>
        </tr>`)
            .join('');
        return this.listPage('چک‌ها', 'cheques', q, noticeText, ['شماره', 'شرکت', 'حساب', 'مبلغ', 'سررسید', 'وضعیت چک', 'صیاد', 'پیوست', 'رکورد', 'عملیات'], rows, 'شماره چک، شرکت، حساب، مبلغ...');
    }
    async editCheque(id, noticeText) {
        const data = await this.adminService.cheque(id);
        const item = data.item;
        const companyOptions = data.companies
            .map((company) => this.option(company.id, company.name, item.companyId))
            .join('');
        const accountOptions = data.bankAccounts
            .map((account) => this.option(account.id, account.accountTitle || account.bankName, item.bankAccountId))
            .join('');
        return (0, admin_view_1.layout)(`ویرایش چک ${item.chequeNumber}`, `${(0, admin_view_1.notice)(noticeText)}<div class="page-title"><h1>ویرایش چک</h1></div>
       <form class="form-card" method="post" action="/admin/cheques/${item.id}">${this.csrfInput()}
        <div class="grid">
          ${this.field('شماره چک', 'chequeNumber', item.chequeNumber)}
          ${this.field('مبلغ (ریال)', 'amount', item.amount, 'number')}
          ${this.selectField('شرکت', 'companyId', companyOptions)}
          ${this.selectField('حساب بانکی', 'bankAccountId', accountOptions)}
          ${this.field('تاریخ صدور', 'chequeDate', (0, admin_view_1.inputDate)(item.chequeDate), 'date')}
          ${this.field('تاریخ سررسید', 'dueDate', (0, admin_view_1.inputDate)(item.dueDate), 'date')}
          ${this.field('وضعیت چک', 'status', item.status)}
          ${this.field('وضعیت صیاد', 'sayadStatus', item.sayadStatus)}
          ${this.field('شناسه صیاد', 'sayadId', item.sayadId)}
          ${this.booleanSelect('ثبت شده در صیاد', 'isRegisteredInSayad', item.isRegisteredInSayad === true)}
          ${this.textarea('توضیحات', 'description', item.description)}
          ${this.recordState(item.archivedAt, item.deletedAt)}
          <div class="field full muted">تعداد پیوست‌های دیتابیس: ${item.attachments.length}</div>
          ${this.systemInfo(item)}
        </div>${this.saveActions('/admin/cheques')}</form>
       ${this.dangerZone(`/admin/cheques/${item.id}/hard-delete`, `چک ${item.chequeNumber}`)}`, 'cheques');
    }
    async updateCheque(id, body, response) {
        this.verifyCsrf(body._csrf);
        await this.adminService.updateCheque(id, body);
        return response.redirect(303, this.withNotice(`/admin/cheques/${id}/edit`, 'تغییرات چک ذخیره شد.'));
    }
    async hardDeleteCheque(id, body, response) {
        this.verifyHardDelete(body);
        await this.adminService.hardDeleteCheque(id);
        return response.redirect(303, this.withNotice('/admin/cheques', 'چک و وابستگی‌های دیتابیسی آن دائمی حذف شد.'));
    }
    async cashPayments(q = '', noticeText) {
        const items = await this.adminService.cashPayments(q);
        const csrf = this.csrfToken();
        const rows = items
            .map((item) => `<tr>
          <td>${(0, admin_view_1.formatDate)(item.paymentDate)}</td>
          <td><strong>${(0, admin_view_1.escapeHtml)(item.company.name)}</strong></td>
          <td>${(0, admin_view_1.escapeHtml)(item.bankAccount.accountTitle || item.bankAccount.bankName)}</td>
          <td>${(0, admin_view_1.formatAmount)(item.amount)} ریال</td>
          <td>${(0, admin_view_1.escapeHtml)(this.paymentMethodLabel(item.paymentMethod))}</td>
          <td>${(0, admin_view_1.escapeHtml)(item.trackingNumber || '—')}</td>
          <td>${item._count.attachments}</td>
          <td>${item.deletedAt ? (0, admin_view_1.statusBadge)('DELETED') : item.archivedAt ? (0, admin_view_1.statusBadge)('ARCHIVED') : (0, admin_view_1.statusBadge)('ACTIVE')}</td>
          <td><div class="row-actions"><a class="button secondary" href="/admin/cash-payments/${item.id}/edit">ویرایش</a>${(0, admin_view_1.hardDeleteForm)(`/admin/cash-payments/${item.id}/hard-delete`, csrf, `واریزی ${item.company.name}`)}</div></td>
        </tr>`)
            .join('');
        return this.listPage('واریزی‌ها', 'cash', q, noticeText, ['تاریخ', 'شرکت', 'حساب', 'مبلغ', 'روش', 'پیگیری', 'پیوست', 'وضعیت', 'عملیات'], rows, 'شرکت، حساب، مبلغ، شماره پیگیری...');
    }
    async editCashPayment(id, noticeText) {
        const data = await this.adminService.cashPayment(id);
        const item = data.item;
        const companyOptions = data.companies.map((company) => this.option(company.id, company.name, item.companyId)).join('');
        const accountOptions = data.bankAccounts.map((account) => this.option(account.id, account.accountTitle || account.bankName, item.bankAccountId)).join('');
        const methodOptions = [
            this.option('BANK_DEPOSIT', 'واریز بانکی', item.paymentMethod),
            this.option('POS_PAYMENT', 'پرداخت کارتخوان', item.paymentMethod),
        ].join('');
        return (0, admin_view_1.layout)('ویرایش واریزی', `${(0, admin_view_1.notice)(noticeText)}<div class="page-title"><h1>ویرایش واریزی</h1></div>
       <form class="form-card" method="post" action="/admin/cash-payments/${item.id}">${this.csrfInput()}
        <div class="grid">
          ${this.field('مبلغ (ریال)', 'amount', item.amount, 'number')}
          ${this.field('تاریخ پرداخت', 'paymentDate', (0, admin_view_1.inputDate)(item.paymentDate), 'date')}
          ${this.selectField('شرکت', 'companyId', companyOptions)}
          ${this.selectField('حساب بانکی', 'bankAccountId', accountOptions)}
          ${this.selectField('روش پرداخت', 'paymentMethod', methodOptions)}
          ${this.field('شماره پیگیری', 'trackingNumber', item.trackingNumber)}
          ${this.textarea('شرح', 'description', item.description)}
          ${this.textarea('یادداشت', 'notes', item.notes)}
          ${this.recordState(item.archivedAt, item.deletedAt)}
          <div class="field full muted">تعداد پیوست‌های دیتابیس: ${item.attachments.length}</div>
          ${this.systemInfo(item)}
        </div>${this.saveActions('/admin/cash-payments')}</form>
       ${this.dangerZone(`/admin/cash-payments/${item.id}/hard-delete`, `واریزی ${item.company.name}`)}`, 'cash');
    }
    async updateCashPayment(id, body, response) {
        this.verifyCsrf(body._csrf);
        await this.adminService.updateCashPayment(id, body);
        return response.redirect(303, this.withNotice(`/admin/cash-payments/${id}/edit`, 'تغییرات واریزی ذخیره شد.'));
    }
    async hardDeleteCashPayment(id, body, response) {
        this.verifyHardDelete(body);
        await this.adminService.hardDeleteCashPayment(id);
        return response.redirect(303, this.withNotice('/admin/cash-payments', 'واریزی و وابستگی‌های دیتابیسی آن دائمی حذف شد.'));
    }
    async users(q = '', noticeText) {
        const items = await this.adminService.users(q);
        const csrf = this.csrfToken();
        const rows = items
            .map((item) => `<tr>
          <td><strong>${(0, admin_view_1.escapeHtml)(item.displayName)}</strong></td><td class="system">${(0, admin_view_1.escapeHtml)(item.username)}</td>
          <td>${(0, admin_view_1.escapeHtml)(item.role === 'MANAGER' ? 'مدیر' : 'کارمند')}</td>
          <td>${item.isActive ? (0, admin_view_1.statusBadge)('ACTIVE') : '<span class="badge danger">غیرفعال</span>'}</td>
          <td>${item.managerAppAccess ? '✓' : '—'}</td><td>${item.canCreateOrders ? '✓' : '—'}</td><td>${item.canCreateCheques ? '✓' : '—'}</td><td>${item.canCreateCashPayments ? '✓' : '—'}</td><td>${item.canViewFinancialReports ? '✓' : '—'}</td>
          <td>${item._count.sessions}</td><td>${item._count.pushDevices}</td>
          <td><div class="row-actions"><a class="button secondary" href="/admin/users/${item.id}/edit">ویرایش</a>${(0, admin_view_1.hardDeleteForm)(`/admin/users/${item.id}/hard-delete`, csrf, item.displayName)}</div></td>
        </tr>`)
            .join('');
        return this.listPage('کاربران', 'users', q, noticeText, ['نام', 'نام کاربری', 'نقش', 'وضعیت', 'Manager', 'سفارش', 'چک', 'واریزی', 'گزارش مالی', 'Session', 'دستگاه', 'عملیات'], rows, 'نام، نام کاربری، نقش...');
    }
    async editUser(id, noticeText) {
        const item = await this.adminService.user(id);
        const roleOptions = [this.option('MANAGER', 'مدیر', item.role), this.option('STAFF', 'کارمند', item.role)].join('');
        return (0, admin_view_1.layout)(`ویرایش ${item.displayName}`, `${(0, admin_view_1.notice)(noticeText)}<div class="page-title"><h1>ویرایش کاربر</h1></div>
       <form class="form-card" method="post" action="/admin/users/${item.id}">${this.csrfInput()}
        <div class="grid">
          ${this.field('نام نمایشی', 'displayName', item.displayName)}
          ${this.field('نام کاربری', 'username', item.username)}
          ${this.selectField('نقش', 'role', roleOptions)}
          ${this.booleanSelect('وضعیت حساب', 'isActive', item.isActive, 'فعال', 'غیرفعال')}
          ${this.field('رمز جدید (خالی یعنی بدون تغییر)', 'password', '', 'password')}
          ${this.checkbox('دسترسی به اپ Manager', 'managerAppAccess', item.managerAppAccess)}
          ${this.checkbox('ثبت سفارش', 'canCreateOrders', item.canCreateOrders)}
          ${this.checkbox('ثبت چک', 'canCreateCheques', item.canCreateCheques)}
          ${this.checkbox('ثبت واریزی', 'canCreateCashPayments', item.canCreateCashPayments)}
          ${this.checkbox('گزارش‌های مالی', 'canViewFinancialReports', item.canViewFinancialReports)}
          <div class="field full muted">Sessionها: ${item._count.sessions} — دستگاه‌ها: ${item._count.pushDevices}. تغییر رمز یا غیرفعال‌سازی، Sessionهای فعال را باطل می‌کند.</div>
          ${this.systemInfo(item)}
        </div>${this.saveActions('/admin/users')}</form>
       ${this.dangerZone(`/admin/users/${item.id}/hard-delete`, item.displayName)}`, 'users');
    }
    async updateUser(id, body, response) {
        this.verifyCsrf(body._csrf);
        await this.adminService.updateUser(id, body);
        return response.redirect(303, this.withNotice(`/admin/users/${id}/edit`, 'تغییرات کاربر ذخیره شد.'));
    }
    async hardDeleteUser(id, body, response) {
        this.verifyHardDelete(body);
        await this.adminService.hardDeleteUser(id);
        return response.redirect(303, this.withNotice('/admin/users', 'کاربر، Sessionها و دستگاه‌هایش دائمی حذف شدند.'));
    }
    async orders(q = '', status = '', noticeText) {
        const items = await this.adminService.orders(q, status);
        const csrf = this.csrfToken();
        const rows = items
            .map((item) => `<tr>
          <td><strong>${(0, admin_view_1.escapeHtml)(item.itemText)}</strong></td>
          <td>${(0, admin_view_1.escapeHtml)(item.category === 'DRUG' ? 'دارو' : 'کالا')}</td>
          <td>${item.requestedQuantity ?? '—'}</td><td>${item.orderedQuantity ?? '—'}</td>
          <td>${(0, admin_view_1.escapeHtml)(item.assignedCompany?.name || item.suggestedCompanyText || '—')}</td>
          <td>${(0, admin_view_1.escapeHtml)(item.requestedByName)}</td><td>${(0, admin_view_1.statusBadge)(item.status)}</td>
          <td>${item.possibleDuplicate ? '<span class="badge warn">مشابه</span>' : '—'}</td>
          <td>${(0, admin_view_1.formatDate)(item.createdAt)}</td>
          <td><div class="row-actions"><a class="button secondary" href="/admin/orders/${item.id}/edit">ویرایش</a>${(0, admin_view_1.hardDeleteForm)(`/admin/orders/${item.id}/hard-delete`, csrf, item.itemText)}</div></td>
        </tr>`)
            .join('');
        const statusOptions = [
            this.option('', 'همه وضعیت‌ها', status),
            this.option('PENDING', 'در انتظار', status),
            this.option('ORDERED', 'سفارش‌شده', status),
            this.option('RECEIVED', 'دریافت‌شده', status),
            this.option('CANCELED', 'لغوشده', status),
            this.option('DELETED', 'حذف‌شده', status),
        ].join('');
        const extraFilter = `<select name="status">${statusOptions}</select>`;
        return this.listPage('سفارشات', 'orders', q, noticeText, ['آیتم', 'گروه', 'درخواستی', 'سفارش‌شده', 'شرکت', 'درخواست‌کننده', 'وضعیت', 'مشابه', 'ثبت', 'عملیات'], rows, 'نام آیتم، شرکت، کاربر، توضیحات...', extraFilter);
    }
    async editOrder(id, noticeText) {
        const data = await this.adminService.order(id);
        const item = data.item;
        const companyOptions = [this.option('', 'بدون شرکت', item.assignedCompanyId), ...data.companies.map((company) => this.option(company.id, company.name, item.assignedCompanyId))].join('');
        const categoryOptions = [this.option('DRUG', 'دارو', item.category), this.option('GOODS', 'کالا', item.category)].join('');
        const statusOptions = ['PENDING', 'ORDERED', 'RECEIVED', 'CANCELED', 'DELETED'].map((value) => this.option(value, this.orderStatusLabel(value), item.status)).join('');
        return (0, admin_view_1.layout)(`ویرایش ${item.itemText}`, `${(0, admin_view_1.notice)(noticeText)}<div class="page-title"><h1>ویرایش سفارش</h1></div>
       <form class="form-card" method="post" action="/admin/orders/${item.id}">${this.csrfInput()}
        <div class="grid">
          ${this.selectField('گروه', 'category', categoryOptions)}
          ${this.field('نام آیتم', 'itemText', item.itemText)}
          ${this.field('تعداد درخواستی', 'requestedQuantity', item.requestedQuantity, 'number')}
          ${this.field('تعداد سفارش‌شده', 'orderedQuantity', item.orderedQuantity, 'number')}
          ${this.field('شرکت پیشنهادی', 'suggestedCompanyText', item.suggestedCompanyText)}
          ${this.selectField('شرکت تخصیص‌یافته', 'assignedCompanyId', companyOptions)}
          ${this.selectField('وضعیت', 'status', statusOptions)}
          ${this.checkbox('احتمال درخواست مشابه', 'possibleDuplicate', item.possibleDuplicate)}
          ${this.field('درخواست‌کننده', 'requestedByName', item.requestedByName)}
          ${this.field('سفارش‌دهنده', 'orderedByName', item.orderedByName)}
          ${this.field('تأییدکننده دریافت', 'receivedByName', item.receivedByName)}
          ${this.field('لغوکننده', 'canceledByName', item.canceledByName)}
          ${this.field('حذف‌کننده', 'deletedByName', item.deletedByName)}
          ${this.field('زمان سفارش', 'orderedAt', (0, admin_view_1.inputDateTime)(item.orderedAt), 'datetime-local')}
          ${this.field('زمان دریافت', 'receivedAt', (0, admin_view_1.inputDateTime)(item.receivedAt), 'datetime-local')}
          ${this.field('زمان لغو', 'canceledAt', (0, admin_view_1.inputDateTime)(item.canceledAt), 'datetime-local')}
          ${this.field('زمان حذف نرم', 'deletedAt', (0, admin_view_1.inputDateTime)(item.deletedAt), 'datetime-local')}
          ${this.textarea('یادداشت', 'notes', item.notes)}
          <div class="field full muted">عکس سفارش: ${item.photoStorageKey ? 'موجود' : 'ندارد'} — UUIDهای کاربران برای حفظ تاریخچه تغییر نمی‌کنند.</div>
          ${this.systemInfo(item)}
        </div>${this.saveActions('/admin/orders')}</form>
       ${this.dangerZone(`/admin/orders/${item.id}/hard-delete`, item.itemText)}`, 'orders');
    }
    async updateOrder(id, body, response) {
        this.verifyCsrf(body._csrf);
        await this.adminService.updateOrder(id, body);
        return response.redirect(303, this.withNotice(`/admin/orders/${id}/edit`, 'تغییرات سفارش ذخیره شد.'));
    }
    async hardDeleteOrder(id, body, response) {
        this.verifyHardDelete(body);
        await this.adminService.hardDeleteOrder(id);
        return response.redirect(303, this.withNotice('/admin/orders', 'سفارش به‌صورت دائمی حذف شد.'));
    }
    async auditLogs(q = '', noticeText) {
        const items = await this.adminService.auditLogs(q);
        const csrf = this.csrfToken();
        const rows = items
            .map((item) => {
            const beforeText = item.beforeData == null ? '—' : JSON.stringify(item.beforeData, null, 2);
            const afterText = item.afterData == null ? '—' : JSON.stringify(item.afterData, null, 2);
            return `<tr>
          <td>${(0, admin_view_1.formatDate)(item.createdAt)}</td><td><strong>${(0, admin_view_1.escapeHtml)(item.actorDisplayName || '—')}</strong></td>
          <td>${(0, admin_view_1.escapeHtml)(item.source)}</td><td>${(0, admin_view_1.escapeHtml)(item.action)}</td><td>${(0, admin_view_1.escapeHtml)(item.entityType)}</td>
          <td class="system">${(0, admin_view_1.escapeHtml)(item.entityId || '—')}</td>
          <td><details><summary>قبل</summary><pre class="audit-json">${(0, admin_view_1.escapeHtml)(beforeText)}</pre></details></td>
          <td><details><summary>بعد</summary><pre class="audit-json">${(0, admin_view_1.escapeHtml)(afterText)}</pre></details></td>
          <td>${(0, admin_view_1.hardDeleteForm)(`/admin/audit-logs/${item.id}/hard-delete`, csrf, `رویداد ${item.action}`)}</td>
        </tr>`;
        })
            .join('');
        return this.listPage('تاریخچه تغییرات', 'audit', q, noticeText, ['زمان', 'کاربر', 'منبع', 'عملیات', 'نوع', 'UUID', 'قبل', 'بعد', 'حذف'], rows, 'کاربر، عملیات، نوع، UUID...');
    }
    async hardDeleteAuditLog(id, body, response) {
        this.verifyHardDelete(body);
        await this.adminService.hardDeleteAuditLog(id);
        return response.redirect(303, this.withNotice('/admin/audit-logs', 'رویداد انتخاب‌شده دائمی حذف و عملیات حذف ثبت شد.'));
    }
    listPage(title, active, query, noticeText, headers, rows, placeholder, extraFilter = '') {
        return (0, admin_view_1.layout)(title, `${(0, admin_view_1.notice)(noticeText)}<div class="toolbar"><div class="page-title"><h1>${(0, admin_view_1.escapeHtml)(title)}</h1></div>
       <form class="search" method="get"><input name="q" value="${(0, admin_view_1.escapeHtml)(query)}" placeholder="${(0, admin_view_1.escapeHtml)(placeholder)}">${extraFilter}<button>جستجو</button></form></div>
       <div class="table-wrap"><table><thead><tr>${headers.map((header) => `<th>${(0, admin_view_1.escapeHtml)(header)}</th>`).join('')}</tr></thead>
       <tbody>${rows || `<tr><td colspan="${headers.length}">رکوردی یافت نشد.</td></tr>`}</tbody></table></div>`, active);
    }
    field(label, name, value, type = 'text') {
        return `<div class="field"><label>${(0, admin_view_1.escapeHtml)(label)}</label><input type="${(0, admin_view_1.escapeHtml)(type)}" name="${(0, admin_view_1.escapeHtml)(name)}" value="${(0, admin_view_1.escapeHtml)(value ?? '')}"></div>`;
    }
    textarea(label, name, value) {
        return `<div class="field full"><label>${(0, admin_view_1.escapeHtml)(label)}</label><textarea name="${(0, admin_view_1.escapeHtml)(name)}">${(0, admin_view_1.escapeHtml)(value ?? '')}</textarea></div>`;
    }
    selectField(label, name, options) {
        return `<div class="field"><label>${(0, admin_view_1.escapeHtml)(label)}</label><select name="${(0, admin_view_1.escapeHtml)(name)}">${options}</select></div>`;
    }
    option(value, label, selected) {
        return `<option value="${(0, admin_view_1.escapeHtml)(value)}" ${value === String(selected ?? '') ? 'selected' : ''}>${(0, admin_view_1.escapeHtml)(label)}</option>`;
    }
    checkbox(label, name, checked) {
        return `<div class="field"><label class="check-row"><input type="checkbox" name="${(0, admin_view_1.escapeHtml)(name)}" value="1" ${checked ? 'checked' : ''}>${(0, admin_view_1.escapeHtml)(label)}</label></div>`;
    }
    booleanSelect(label, name, checked, yes = 'بله', no = 'خیر') {
        return this.selectField(label, name, `${this.option('1', yes, checked ? '1' : '0')}${this.option('0', no, checked ? '1' : '0')}`);
    }
    recordState(archivedAt, deletedAt) {
        return `${this.booleanSelect('آرشیو', 'archived', archivedAt != null, 'آرشیوشده', 'فعال')}${this.booleanSelect('حذف نرم', 'softDeleted', deletedAt != null, 'حذف‌شده', 'موجود')}`;
    }
    systemInfo(item) {
        return `<div class="field full muted system">UUID: ${(0, admin_view_1.escapeHtml)(item.id)}<br>Created: ${(0, admin_view_1.formatDate)(item.createdAt)}<br>Updated: ${(0, admin_view_1.formatDate)(item.updatedAt)}</div>`;
    }
    saveActions(backUrl) {
        return `<div class="actions"><button type="submit">ذخیره تغییرات</button><a class="button secondary" href="${(0, admin_view_1.escapeHtml)(backUrl)}">بازگشت</a></div>`;
    }
    dangerZone(action, label, blocked) {
        return `<div class="danger-zone"><h2>منطقه خطر</h2><p>حذف دائمی قابل بازگشت نیست و پس از تأیید با عبارت DELETE انجام می‌شود.</p>${blocked ? `<div class="dependency">${(0, admin_view_1.escapeHtml)(blocked)}</div>` : ''}${(0, admin_view_1.hardDeleteForm)(action, this.csrfToken(), label, blocked)}</div>`;
    }
    sendXlsx(response, baseName, file) {
        const stamp = new Date().toISOString().replace(/[-:]/g, '').slice(0, 13);
        const fileName = `${baseName}-${stamp}.xlsx`;
        response.setHeader('Content-Type', 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
        response.setHeader('Content-Disposition', `attachment; filename="${fileName}"`);
        response.setHeader('Cache-Control', 'no-store, max-age=0');
        response.setHeader('X-Content-Type-Options', 'nosniff');
        response.setHeader('Content-Length', String(file.length));
        response.status(200).send(file);
    }
    excelNumber(value) {
        if (value == null || String(value).trim() === '') {
            return '';
        }
        const text = String(value);
        const number = Number(text);
        return Number.isFinite(number) && Math.abs(number) <= Number.MAX_SAFE_INTEGER
            ? number
            : text;
    }
    excelDateTime(value) {
        if (!value) {
            return '';
        }
        const date = new Date(value);
        return Number.isNaN(date.getTime())
            ? String(value)
            : date.toISOString().replace('T', ' ').slice(0, 19);
    }
    amountOrDash(value) {
        return value == null || String(value).trim() === '' ? '—' : (0, admin_view_1.formatAmount)(value);
    }
    invoiceDocTypeLabel(value, sourceLabel) {
        if (value === 1) {
            return 'خرید';
        }
        if (value === 2) {
            return 'برگشت خرید';
        }
        return sourceLabel || String(value);
    }
    catalogCategoryBadge(value) {
        const category = String(value ?? '').toUpperCase();
        if (category === 'DRUG') {
            return '<span class="badge ok">دارو</span>';
        }
        if (category === 'GOODS') {
            return '<span class="badge">کالا</span>';
        }
        return `<span class="badge">${(0, admin_view_1.escapeHtml)(value || '—')}</span>`;
    }
    catalogListUrl(filters) {
        const params = new URLSearchParams();
        Object.entries(filters).forEach(([key, value]) => {
            const text = String(value ?? '').trim();
            if (text) {
                params.set(key, text);
            }
        });
        const query = params.toString();
        return `/admin/catalog${query ? `?${query}` : ''}`;
    }
    invoiceListUrl(filters) {
        const params = new URLSearchParams();
        Object.entries(filters).forEach(([key, value]) => {
            const text = String(value ?? '').trim();
            if (text) {
                params.set(key, text);
            }
        });
        const query = params.toString();
        return `/admin/invoices${query ? `?${query}` : ''}`;
    }
    paymentMethodLabel(value) {
        return value === 'BANK_DEPOSIT' ? 'واریز بانکی' : value === 'POS_PAYMENT' ? 'پرداخت کارتخوان' : value;
    }
    orderStatusLabel(value) {
        return { PENDING: 'در انتظار', ORDERED: 'سفارش‌شده', RECEIVED: 'دریافت‌شده', CANCELED: 'لغوشده', DELETED: 'حذف‌شده' }[value] ?? value;
    }
    withNotice(path, text) {
        return `${path}${path.includes('?') ? '&' : '?'}notice=${encodeURIComponent(text)}`;
    }
    csrfInput() {
        return `<input type="hidden" name="_csrf" value="${this.csrfToken()}">`;
    }
    csrfToken() {
        return (0, node_crypto_1.createHmac)('sha256', process.env.ADMIN_PASSWORD ?? '')
            .update('pharmaflow-admin-csrf-v1')
            .digest('hex');
    }
    verifyCsrf(value) {
        const expected = Buffer.from(this.csrfToken());
        const received = Buffer.from(String(value ?? ''));
        if (expected.length !== received.length || !(0, node_crypto_1.timingSafeEqual)(expected, received)) {
            throw new common_1.ForbiddenException('Invalid CSRF token.');
        }
    }
    verifyHardDelete(body) {
        this.verifyCsrf(body._csrf);
        if (body._confirmation !== 'DELETE') {
            throw new common_1.ForbiddenException('Hard delete confirmation is invalid.');
        }
    }
};
exports.AdminController = AdminController;
__decorate([
    (0, common_1.Get)(),
    (0, common_1.Header)('Content-Type', 'text/html; charset=utf-8'),
    __param(0, (0, common_1.Query)('notice')),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String]),
    __metadata("design:returntype", Promise)
], AdminController.prototype, "dashboard", null);
__decorate([
    (0, common_1.Get)('release'),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", []),
    __metadata("design:returntype", void 0)
], AdminController.prototype, "release", null);
__decorate([
    (0, common_1.Get)('catalog'),
    (0, common_1.Header)('Content-Type', 'text/html; charset=utf-8'),
    __param(0, (0, common_1.Query)('q')),
    __param(1, (0, common_1.Query)('category')),
    __param(2, (0, common_1.Query)('active')),
    __param(3, (0, common_1.Query)('shape')),
    __param(4, (0, common_1.Query)('sort')),
    __param(5, (0, common_1.Query)('page')),
    __param(6, (0, common_1.Query)('pageSize')),
    __param(7, (0, common_1.Query)('notice')),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Object, Object, Object, Object, Object, Object, Object, String]),
    __metadata("design:returntype", Promise)
], AdminController.prototype, "catalog", null);
__decorate([
    (0, common_1.Get)('catalog/export'),
    __param(0, (0, common_1.Query)('q')),
    __param(1, (0, common_1.Query)('category')),
    __param(2, (0, common_1.Query)('active')),
    __param(3, (0, common_1.Query)('shape')),
    __param(4, (0, common_1.Query)('sort')),
    __param(5, (0, common_1.Res)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Object, Object, Object, Object, Object, Object]),
    __metadata("design:returntype", Promise)
], AdminController.prototype, "exportCatalog", null);
__decorate([
    (0, common_1.Get)('catalog/pdf'),
    (0, common_1.Header)('Content-Type', 'text/html; charset=utf-8'),
    (0, common_1.Header)('Cache-Control', 'no-store, max-age=0'),
    __param(0, (0, common_1.Query)('q')),
    __param(1, (0, common_1.Query)('category')),
    __param(2, (0, common_1.Query)('active')),
    __param(3, (0, common_1.Query)('shape')),
    __param(4, (0, common_1.Query)('sort')),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Object, Object, Object, Object, Object]),
    __metadata("design:returntype", Promise)
], AdminController.prototype, "exportCatalogPdf", null);
__decorate([
    (0, common_1.Get)('catalog/:id'),
    (0, common_1.Header)('Content-Type', 'text/html; charset=utf-8'),
    __param(0, (0, common_1.Param)('id')),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String]),
    __metadata("design:returntype", Promise)
], AdminController.prototype, "catalogItem", null);
__decorate([
    (0, common_1.Get)('invoices'),
    (0, common_1.Header)('Content-Type', 'text/html; charset=utf-8'),
    __param(0, (0, common_1.Query)('invoiceNumber')),
    __param(1, (0, common_1.Query)('companyId')),
    __param(2, (0, common_1.Query)('docType')),
    __param(3, (0, common_1.Query)('dateFrom')),
    __param(4, (0, common_1.Query)('dateTo')),
    __param(5, (0, common_1.Query)('page')),
    __param(6, (0, common_1.Query)('pageSize')),
    __param(7, (0, common_1.Query)('notice')),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Object, Object, Object, Object, Object, Object, Object, String]),
    __metadata("design:returntype", Promise)
], AdminController.prototype, "invoices", null);
__decorate([
    (0, common_1.Get)('invoices/settlement/new'),
    (0, common_1.Header)('Content-Type', 'text/html; charset=utf-8'),
    __param(0, (0, common_1.Query)('kind')),
    __param(1, (0, common_1.Query)('invoiceIds')),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Object, Object]),
    __metadata("design:returntype", Promise)
], AdminController.prototype, "newInvoiceSettlement", null);
__decorate([
    (0, common_1.Post)('invoices/settlement'),
    __param(0, (0, common_1.Body)()),
    __param(1, (0, common_1.Res)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Object, Object]),
    __metadata("design:returntype", Promise)
], AdminController.prototype, "createInvoiceSettlement", null);
__decorate([
    (0, common_1.Get)('invoices/export'),
    __param(0, (0, common_1.Query)('invoiceNumber')),
    __param(1, (0, common_1.Query)('companyId')),
    __param(2, (0, common_1.Query)('docType')),
    __param(3, (0, common_1.Query)('dateFrom')),
    __param(4, (0, common_1.Query)('dateTo')),
    __param(5, (0, common_1.Res)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Object, Object, Object, Object, Object, Object]),
    __metadata("design:returntype", Promise)
], AdminController.prototype, "exportInvoices", null);
__decorate([
    (0, common_1.Get)('invoices/pdf'),
    (0, common_1.Header)('Content-Type', 'text/html; charset=utf-8'),
    (0, common_1.Header)('Cache-Control', 'no-store, max-age=0'),
    __param(0, (0, common_1.Query)('invoiceNumber')),
    __param(1, (0, common_1.Query)('companyId')),
    __param(2, (0, common_1.Query)('docType')),
    __param(3, (0, common_1.Query)('dateFrom')),
    __param(4, (0, common_1.Query)('dateTo')),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Object, Object, Object, Object, Object]),
    __metadata("design:returntype", Promise)
], AdminController.prototype, "exportInvoicesPdf", null);
__decorate([
    (0, common_1.Get)('invoices/:id'),
    (0, common_1.Header)('Content-Type', 'text/html; charset=utf-8'),
    __param(0, (0, common_1.Param)('id')),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String]),
    __metadata("design:returntype", Promise)
], AdminController.prototype, "invoice", null);
__decorate([
    (0, common_1.Get)('companies'),
    (0, common_1.Header)('Content-Type', 'text/html; charset=utf-8'),
    __param(0, (0, common_1.Query)('q')),
    __param(1, (0, common_1.Query)('notice')),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Object, String]),
    __metadata("design:returntype", Promise)
], AdminController.prototype, "companies", null);
__decorate([
    (0, common_1.Get)('companies/export'),
    __param(0, (0, common_1.Query)('q')),
    __param(1, (0, common_1.Res)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Object, Object]),
    __metadata("design:returntype", Promise)
], AdminController.prototype, "exportCompanies", null);
__decorate([
    (0, common_1.Get)('companies/pdf'),
    (0, common_1.Header)('Content-Type', 'text/html; charset=utf-8'),
    (0, common_1.Header)('Cache-Control', 'no-store, max-age=0'),
    __param(0, (0, common_1.Query)('q')),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Object]),
    __metadata("design:returntype", Promise)
], AdminController.prototype, "exportCompaniesPdf", null);
__decorate([
    (0, common_1.Get)('companies/:id/edit'),
    (0, common_1.Header)('Content-Type', 'text/html; charset=utf-8'),
    __param(0, (0, common_1.Param)('id')),
    __param(1, (0, common_1.Query)('notice')),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, String]),
    __metadata("design:returntype", Promise)
], AdminController.prototype, "editCompany", null);
__decorate([
    (0, common_1.Post)('companies/:id'),
    __param(0, (0, common_1.Param)('id')),
    __param(1, (0, common_1.Body)()),
    __param(2, (0, common_1.Res)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, Object, Object]),
    __metadata("design:returntype", Promise)
], AdminController.prototype, "updateCompany", null);
__decorate([
    (0, common_1.Post)('companies/:id/hard-delete'),
    __param(0, (0, common_1.Param)('id')),
    __param(1, (0, common_1.Body)()),
    __param(2, (0, common_1.Res)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, Object, Object]),
    __metadata("design:returntype", Promise)
], AdminController.prototype, "hardDeleteCompany", null);
__decorate([
    (0, common_1.Get)('bank-accounts'),
    (0, common_1.Header)('Content-Type', 'text/html; charset=utf-8'),
    __param(0, (0, common_1.Query)('q')),
    __param(1, (0, common_1.Query)('notice')),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Object, String]),
    __metadata("design:returntype", Promise)
], AdminController.prototype, "bankAccounts", null);
__decorate([
    (0, common_1.Get)('bank-accounts/:id/edit'),
    (0, common_1.Header)('Content-Type', 'text/html; charset=utf-8'),
    __param(0, (0, common_1.Param)('id')),
    __param(1, (0, common_1.Query)('notice')),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, String]),
    __metadata("design:returntype", Promise)
], AdminController.prototype, "editBankAccount", null);
__decorate([
    (0, common_1.Post)('bank-accounts/:id'),
    __param(0, (0, common_1.Param)('id')),
    __param(1, (0, common_1.Body)()),
    __param(2, (0, common_1.Res)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, Object, Object]),
    __metadata("design:returntype", Promise)
], AdminController.prototype, "updateBankAccount", null);
__decorate([
    (0, common_1.Post)('bank-accounts/:id/hard-delete'),
    __param(0, (0, common_1.Param)('id')),
    __param(1, (0, common_1.Body)()),
    __param(2, (0, common_1.Res)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, Object, Object]),
    __metadata("design:returntype", Promise)
], AdminController.prototype, "hardDeleteBankAccount", null);
__decorate([
    (0, common_1.Get)('cheques'),
    (0, common_1.Header)('Content-Type', 'text/html; charset=utf-8'),
    __param(0, (0, common_1.Query)('q')),
    __param(1, (0, common_1.Query)('notice')),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Object, String]),
    __metadata("design:returntype", Promise)
], AdminController.prototype, "cheques", null);
__decorate([
    (0, common_1.Get)('cheques/:id/edit'),
    (0, common_1.Header)('Content-Type', 'text/html; charset=utf-8'),
    __param(0, (0, common_1.Param)('id')),
    __param(1, (0, common_1.Query)('notice')),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, String]),
    __metadata("design:returntype", Promise)
], AdminController.prototype, "editCheque", null);
__decorate([
    (0, common_1.Post)('cheques/:id'),
    __param(0, (0, common_1.Param)('id')),
    __param(1, (0, common_1.Body)()),
    __param(2, (0, common_1.Res)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, Object, Object]),
    __metadata("design:returntype", Promise)
], AdminController.prototype, "updateCheque", null);
__decorate([
    (0, common_1.Post)('cheques/:id/hard-delete'),
    __param(0, (0, common_1.Param)('id')),
    __param(1, (0, common_1.Body)()),
    __param(2, (0, common_1.Res)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, Object, Object]),
    __metadata("design:returntype", Promise)
], AdminController.prototype, "hardDeleteCheque", null);
__decorate([
    (0, common_1.Get)('cash-payments'),
    (0, common_1.Header)('Content-Type', 'text/html; charset=utf-8'),
    __param(0, (0, common_1.Query)('q')),
    __param(1, (0, common_1.Query)('notice')),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Object, String]),
    __metadata("design:returntype", Promise)
], AdminController.prototype, "cashPayments", null);
__decorate([
    (0, common_1.Get)('cash-payments/:id/edit'),
    (0, common_1.Header)('Content-Type', 'text/html; charset=utf-8'),
    __param(0, (0, common_1.Param)('id')),
    __param(1, (0, common_1.Query)('notice')),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, String]),
    __metadata("design:returntype", Promise)
], AdminController.prototype, "editCashPayment", null);
__decorate([
    (0, common_1.Post)('cash-payments/:id'),
    __param(0, (0, common_1.Param)('id')),
    __param(1, (0, common_1.Body)()),
    __param(2, (0, common_1.Res)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, Object, Object]),
    __metadata("design:returntype", Promise)
], AdminController.prototype, "updateCashPayment", null);
__decorate([
    (0, common_1.Post)('cash-payments/:id/hard-delete'),
    __param(0, (0, common_1.Param)('id')),
    __param(1, (0, common_1.Body)()),
    __param(2, (0, common_1.Res)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, Object, Object]),
    __metadata("design:returntype", Promise)
], AdminController.prototype, "hardDeleteCashPayment", null);
__decorate([
    (0, common_1.Get)('users'),
    (0, common_1.Header)('Content-Type', 'text/html; charset=utf-8'),
    __param(0, (0, common_1.Query)('q')),
    __param(1, (0, common_1.Query)('notice')),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Object, String]),
    __metadata("design:returntype", Promise)
], AdminController.prototype, "users", null);
__decorate([
    (0, common_1.Get)('users/:id/edit'),
    (0, common_1.Header)('Content-Type', 'text/html; charset=utf-8'),
    __param(0, (0, common_1.Param)('id')),
    __param(1, (0, common_1.Query)('notice')),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, String]),
    __metadata("design:returntype", Promise)
], AdminController.prototype, "editUser", null);
__decorate([
    (0, common_1.Post)('users/:id'),
    __param(0, (0, common_1.Param)('id')),
    __param(1, (0, common_1.Body)()),
    __param(2, (0, common_1.Res)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, Object, Object]),
    __metadata("design:returntype", Promise)
], AdminController.prototype, "updateUser", null);
__decorate([
    (0, common_1.Post)('users/:id/hard-delete'),
    __param(0, (0, common_1.Param)('id')),
    __param(1, (0, common_1.Body)()),
    __param(2, (0, common_1.Res)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, Object, Object]),
    __metadata("design:returntype", Promise)
], AdminController.prototype, "hardDeleteUser", null);
__decorate([
    (0, common_1.Get)('orders'),
    (0, common_1.Header)('Content-Type', 'text/html; charset=utf-8'),
    __param(0, (0, common_1.Query)('q')),
    __param(1, (0, common_1.Query)('status')),
    __param(2, (0, common_1.Query)('notice')),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Object, Object, String]),
    __metadata("design:returntype", Promise)
], AdminController.prototype, "orders", null);
__decorate([
    (0, common_1.Get)('orders/:id/edit'),
    (0, common_1.Header)('Content-Type', 'text/html; charset=utf-8'),
    __param(0, (0, common_1.Param)('id')),
    __param(1, (0, common_1.Query)('notice')),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, String]),
    __metadata("design:returntype", Promise)
], AdminController.prototype, "editOrder", null);
__decorate([
    (0, common_1.Post)('orders/:id'),
    __param(0, (0, common_1.Param)('id')),
    __param(1, (0, common_1.Body)()),
    __param(2, (0, common_1.Res)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, Object, Object]),
    __metadata("design:returntype", Promise)
], AdminController.prototype, "updateOrder", null);
__decorate([
    (0, common_1.Post)('orders/:id/hard-delete'),
    __param(0, (0, common_1.Param)('id')),
    __param(1, (0, common_1.Body)()),
    __param(2, (0, common_1.Res)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, Object, Object]),
    __metadata("design:returntype", Promise)
], AdminController.prototype, "hardDeleteOrder", null);
__decorate([
    (0, common_1.Get)('audit-logs'),
    (0, common_1.Header)('Content-Type', 'text/html; charset=utf-8'),
    __param(0, (0, common_1.Query)('q')),
    __param(1, (0, common_1.Query)('notice')),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Object, String]),
    __metadata("design:returntype", Promise)
], AdminController.prototype, "auditLogs", null);
__decorate([
    (0, common_1.Post)('audit-logs/:id/hard-delete'),
    __param(0, (0, common_1.Param)('id')),
    __param(1, (0, common_1.Body)()),
    __param(2, (0, common_1.Res)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, Object, Object]),
    __metadata("design:returntype", Promise)
], AdminController.prototype, "hardDeleteAuditLog", null);
exports.AdminController = AdminController = __decorate([
    (0, common_1.Controller)('admin'),
    __metadata("design:paramtypes", [admin_service_1.AdminService])
], AdminController);
//# sourceMappingURL=admin.controller.js.map