import {
  Body,
  Controller,
  ForbiddenException,
  Get,
  Header,
  Param,
  Post,
  Query,
  Res,
} from '@nestjs/common';
import type { Response } from 'express';
import { createHmac, timingSafeEqual } from 'node:crypto';

import { buildXlsx } from './admin-excel';
import { buildPrintToPdfReport } from './admin-print';
import { AdminService } from './admin.service';
import {
  ADMIN_DASHBOARD_RELEASE,
  escapeHtml,
  formatAmount,
  formatDate,
  hardDeleteForm,
  inputDate,
  inputDateTime,
  invoicePaginationWindow,
  layout,
  notice,
  statusBadge,
} from './admin-view';

type FormBody = Record<string, string | undefined>;

@Controller('admin')
export class AdminController {
  constructor(private readonly adminService: AdminService) {}

  @Get()
  @Header('Content-Type', 'text/html; charset=utf-8')
  async dashboard(@Query('notice') noticeText?: string) {
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
      .map(
        ([href, label, value]) => `
          <a class="card" href="${href}">
            <div class="muted">${label}</div>
            <div class="metric">${formatAmount(value)}</div>
          </a>`,
      )
      .join('');

    return layout(
      'داشبورد مدیریتی',
      `${notice(noticeText)}
       <div class="page-title"><h1>داشبورد کامل مدیریتی</h1></div>
       <div class="cards">${cards}</div>`,
      'dashboard',
    );
  }

  @Get('release')
  release() {
    return {
      release: ADMIN_DASHBOARD_RELEASE,
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

  @Get('catalog')
  @Header('Content-Type', 'text/html; charset=utf-8')
  async catalog(
    @Query('q') q = '',
    @Query('category') category = '',
    @Query('active') active = '',
    @Query('shape') shape = '',
    @Query('sort') sort = 'SYNC_DESC',
    @Query('page') page = '1',
    @Query('pageSize') pageSize = '50',
  ) {
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
      .map((size) =>
        this.option(String(size), String(size), String(data.pageSize)),
      )
      .join('');

    const stats = [
      ['کل اقلام', data.stats.totalItems],
      ['دارو', data.stats.drugCount],
      ['کالا', data.stats.goodsCount],
      ['فعال', data.stats.activeCount],
      ['غیرفعال', data.stats.inactiveCount],
    ]
      .map(
        ([label, value]) => `<div class="card catalog-stat">
          <div class="muted">${escapeHtml(label)}</div>
          <div class="metric">${formatAmount(value)}</div>
        </div>`,
      )
      .join('');

    const rows = data.items
      .map(
        (item) => `<tr>
          <td>${this.catalogCategoryBadge(item.category)}</td>
          <td><strong>${escapeHtml(item.persianName || '—')}</strong></td>
          <td>${escapeHtml(item.genericName || '—')}</td>
          <td>${escapeHtml(item.persianBrandName || '—')}</td>
          <td>${escapeHtml(item.brandName || '—')}</td>
          <td>${escapeHtml(item.unit || '—')}</td>
          <td>${escapeHtml(item.shapeName || '—')}</td>
          <td>${item.packetQuantity == null ? '—' : formatAmount(item.packetQuantity)}</td>
          <td>${this.amountOrDash(item.salesPrice)}</td>
          <td>${this.amountOrDash(item.lastPurchasePrice)}</td>
          <td>${statusBadge(item.isActive ? 'ACTIVE' : 'INACTIVE')}</td>
          <td>${formatDate(item.sourceSyncedAt)}</td>
          <td><a class="button secondary" href="/admin/catalog/${item.id}">جزئیات</a></td>
        </tr>`,
      )
      .join('');

    const pageUrl = (targetPage: number) =>
      this.catalogListUrl({
        q,
        category,
        active,
        shape,
        sort: data.sort,
        page: String(targetPage),
        pageSize: String(data.pageSize),
      });

    const pageWindow = invoicePaginationWindow(data.page, data.totalPages, 10);
    const pageNumberLinks = pageWindow.pages
      .map((pageNumber) =>
        pageNumber === data.page
          ? `<span class="page-link active" aria-current="page">${formatAmount(pageNumber)}</span>`
          : `<a class="page-link" href="${escapeHtml(pageUrl(pageNumber))}">${formatAmount(pageNumber)}</a>`,
      )
      .join('');

    const firstDisabled = data.page <= 1;
    const lastDisabled = data.page >= data.totalPages;
    const firstLink = firstDisabled
      ? '<span class="page-link disabled" aria-disabled="true">&lt;&lt;</span>'
      : `<a class="page-link" href="${escapeHtml(pageUrl(1))}">&lt;&lt;</a>`;
    const previousLink = firstDisabled
      ? '<span class="page-link disabled" aria-disabled="true">&lt;</span>'
      : `<a class="page-link" href="${escapeHtml(pageUrl(data.page - 1))}">&lt;</a>`;
    const nextLink = lastDisabled
      ? '<span class="page-link disabled" aria-disabled="true">&gt;</span>'
      : `<a class="page-link" href="${escapeHtml(pageUrl(data.page + 1))}">&gt;</a>`;
    const lastLink = lastDisabled
      ? '<span class="page-link disabled" aria-disabled="true">&gt;&gt;</span>'
      : `<a class="page-link" href="${escapeHtml(pageUrl(data.totalPages))}">&gt;&gt;</a>`;

    const pagination =
      data.totalPages > 1
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

    const listStateActive = Boolean(
      q ||
        category ||
        active ||
        shape ||
        data.sort !== 'SYNC_DESC' ||
        data.page !== 1 ||
        data.pageSize !== 50,
    );

    return layout(
      'دارو و کالا',
      `<div class="page-title">
         <h1>دارو و کالا</h1>
         <span class="badge">فقط خواندنی از آرسن</span>
       </div>
       <div class="cards catalog-stats">${stats}</div>
       <form class="filters catalog-filters" method="get" action="/admin/catalog" id="catalog-filter-form">
         <div class="field search-field"><label>جستجو</label><input name="q" id="catalog-live-search" value="${escapeHtml(q)}" placeholder="نام فارسی، ژنریک، برند یا شناسه آرسن" autocomplete="off"><span class="muted catalog-live-status" id="catalog-live-status" aria-live="polite"></span></div>
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
           <span class="muted">نتیجه فیلتر: ${formatAmount(data.totalCount)} قلم — ${formatAmount(data.pageSize)} ردیف در هر صفحه</span>
         </div>
         <div class="table-wrap catalog-table"><table><thead><tr>
           ${['نوع', 'نام فارسی', 'نام ژنریک', 'برند فارسی', 'برند انگلیسی', 'واحد/دوز', 'فرم', 'تعداد در بسته', 'قیمت فروش', 'آخرین قیمت خرید', 'وضعیت', 'آخرین Sync', 'عملیات'].map((header) => `<th>${escapeHtml(header)}</th>`).join('')}
         </tr></thead><tbody>
           ${rows || '<tr><td colspan="13">قلمی با این فیلترها پیدا نشد.</td></tr>'}
         </tbody></table></div>
         ${pagination}
         <div class="pagination-summary"><span class="muted">صفحه ${formatAmount(data.page)} از ${formatAmount(data.totalPages)}</span></div>
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
       </script>`,
      'catalog',
    );
  }

  @Get('catalog/export')
  async exportCatalog(
    @Query('q') q = '',
    @Query('category') category = '',
    @Query('active') active = '',
    @Query('shape') shape = '',
    @Query('sort') sort = 'SYNC_DESC',
    @Res() response: Response,
  ) {
    const items = await this.adminService.catalogExport({
      q,
      category,
      active,
      shape,
      sort,
    });

    const file = buildXlsx(
      'دارو و کالا',
      [
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
      ],
      items.map((item) => [
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
      ]),
    );

    return this.sendXlsx(response, 'pharmaflow-catalog', file);
  }

  @Get('catalog/pdf')
  @Header('Content-Type', 'text/html; charset=utf-8')
  @Header('Cache-Control', 'no-store, max-age=0')
  async exportCatalogPdf(
    @Query('q') q = '',
    @Query('category') category = '',
    @Query('active') active = '',
    @Query('shape') shape = '',
    @Query('sort') sort = 'SYNC_DESC',
  ) {
    const items = await this.adminService.catalogExport({
      q,
      category,
      active,
      shape,
      sort,
    });

    return buildPrintToPdfReport(
      'دارو و کالا',
      [
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
      ],
      items.map((item) => [
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
        item.salesPrice == null ? '' : formatAmount(item.salesPrice),
        item.lastPurchasePrice == null
          ? ''
          : formatAmount(item.lastPurchasePrice),
        item.isActive ? 'فعال' : 'غیرفعال',
      ]),
      'همه رکوردهای منطبق با فیلترهای فعلی - بدون محدودیت صفحه‌بندی',
    );
  }

  @Get('catalog/:id')
  @Header('Content-Type', 'text/html; charset=utf-8')
  async catalogItem(@Param('id') id: string) {
    const item = await this.adminService.catalogItem(id);

    return layout(
      item.persianName || item.genericName || `Arsen ${String(item.arsenDrugId)}`,
      `<div class="page-title">
         <h1>${escapeHtml(item.persianName || item.genericName || 'جزئیات قلم')}</h1>
         ${this.catalogCategoryBadge(item.category)}
         ${statusBadge(item.isActive ? 'ACTIVE' : 'INACTIVE')}
         <a class="button secondary" href="/admin/catalog">بازگشت به دارو و کالا</a>
       </div>
       <div class="notice catalog-source-note">این اطلاعات از Master آرسن Sync می‌شود و در داشبورد مدیریتی فقط خواندنی است.</div>
       <div class="form-card"><div class="grid">
         <div class="field"><label>نام فارسی</label><div>${escapeHtml(item.persianName || '—')}</div></div>
         <div class="field"><label>نام ژنریک</label><div>${escapeHtml(item.genericName || '—')}</div></div>
         <div class="field"><label>نام برند فارسی</label><div>${escapeHtml(item.persianBrandName || '—')}</div></div>
         <div class="field"><label>نام برند انگلیسی</label><div>${escapeHtml(item.brandName || '—')}</div></div>
         <div class="field"><label>واحد / دوز</label><div>${escapeHtml(item.unit || '—')}</div></div>
         <div class="field"><label>شکل / فرم</label><div>${escapeHtml(item.shapeName || '—')}</div></div>
         <div class="field"><label>تعداد در بسته</label><div>${item.packetQuantity == null ? '—' : formatAmount(item.packetQuantity)}</div></div>
         <div class="field"><label>قیمت فروش</label><div>${this.amountOrDash(item.salesPrice)}</div></div>
         <div class="field"><label>آخرین قیمت خرید</label><div>${this.amountOrDash(item.lastPurchasePrice)}</div></div>
         <div class="field"><label>وضعیت</label><div>${statusBadge(item.isActive ? 'ACTIVE' : 'INACTIVE')}</div></div>
         ${item.description ? `<div class="field full"><label>توضیحات</label><div class="catalog-description">${escapeHtml(item.description)}</div></div>` : ''}
         <div class="field full muted system">
           Arsen Drug ID: ${escapeHtml(item.arsenDrugId)}<br>
           Category: ${escapeHtml(item.category)}<br>
           Imported: ${formatDate(item.importedAt)}<br>
           Source synced: ${formatDate(item.sourceSyncedAt)}<br>
           UUID: ${escapeHtml(item.id)}
         </div>
       </div></div>`,
      'catalog',
    );
  }

  @Get('invoices')
  @Header('Content-Type', 'text/html; charset=utf-8')
  async invoices(
    @Query('invoiceNumber') invoiceNumber = '',
    @Query('companyId') companyId = '',
    @Query('docType') docType = '',
    @Query('dateFrom') dateFrom = '',
    @Query('dateTo') dateTo = '',
    @Query('page') page = '1',
    @Query('pageSize') pageSize = '50',
  ) {
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
      ...data.companies.map((company) =>
        this.option(company.id, company.name, companyId),
      ),
    ].join('');
    const docTypeOptions = [
      this.option('', 'خرید و برگشت خرید', docType),
      this.option('1', 'خرید', docType),
      this.option('2', 'برگشت خرید', docType),
    ].join('');
    const pageSizeOptions = [25, 50, 100, 200]
      .map((size) =>
        this.option(String(size), String(size), String(data.pageSize)),
      )
      .join('');

    const rows = data.items
      .map(
        (item) => `<tr>
          <td>${escapeHtml(item.invoiceDate || '—')}</td>
          <td><strong>${escapeHtml(item.invoiceNumber || '—')}</strong></td>
          <td>${escapeHtml(item.company.name)}</td>
          <td>${escapeHtml(this.invoiceDocTypeLabel(item.factorDocType, item.factorDocTypeName))}</td>
          <td>${this.amountOrDash(item.factorPayablePrice)}</td>
          <td>${escapeHtml(item.settlementDate || '—')}</td>
          <td>${formatAmount(item.itemCount)}</td>
          <td>${formatDate(item.importedAt)}</td>
          <td>${item.isDeletedInArsen ? statusBadge('DELETED') : statusBadge('ACTIVE')}</td>
          <td><a class="button secondary" href="/admin/invoices/${item.id}">جزئیات</a></td>
        </tr>`,
      )
      .join('');

    const pageUrl = (targetPage: number) =>
      this.invoiceListUrl({
        invoiceNumber,
        companyId,
        docType,
        dateFrom,
        dateTo,
        page: String(targetPage),
        pageSize: String(data.pageSize),
      });

    const pageWindow = invoicePaginationWindow(
      data.page,
      data.totalPages,
      10,
    );

    const pageNumberLinks = pageWindow.pages
      .map((pageNumber) =>
        pageNumber === data.page
          ? `<span class="page-link active" aria-current="page">${formatAmount(pageNumber)}</span>`
          : `<a class="page-link" href="${escapeHtml(pageUrl(pageNumber))}">${formatAmount(pageNumber)}</a>`,
      )
      .join('');

    const firstDisabled = data.page <= 1;
    const lastDisabled = data.page >= data.totalPages;

    const firstLink = firstDisabled
      ? '<span class="page-link disabled" aria-disabled="true">&lt;&lt;</span>'
      : `<a class="page-link" href="${escapeHtml(pageUrl(1))}">&lt;&lt;</a>`;

    const previousLink = firstDisabled
      ? '<span class="page-link disabled" aria-disabled="true">&lt;</span>'
      : `<a class="page-link" href="${escapeHtml(pageUrl(data.page - 1))}">&lt;</a>`;

    const nextLink = lastDisabled
      ? '<span class="page-link disabled" aria-disabled="true">&gt;</span>'
      : `<a class="page-link" href="${escapeHtml(pageUrl(data.page + 1))}">&gt;</a>`;

    const lastLink = lastDisabled
      ? '<span class="page-link disabled" aria-disabled="true">&gt;&gt;</span>'
      : `<a class="page-link" href="${escapeHtml(pageUrl(data.totalPages))}">&gt;&gt;</a>`;

    const pagination =
      data.totalPages > 1
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

    const filtersActive = Boolean(
      invoiceNumber || companyId || docType || dateFrom || dateTo,
    );
    const listStateActive =
      filtersActive || data.page !== 1 || data.pageSize !== 50;

    return layout(
      'فاکتورها',
      `<div class="page-title"><h1>فاکتورها</h1></div>
       <form class="filters invoice-filters" method="get" action="/admin/invoices" id="invoice-filter-form">
         <div class="field"><label>شماره فاکتور</label><input name="invoiceNumber" id="invoice-live-search" value="${escapeHtml(invoiceNumber)}" placeholder="بخشی از شماره فاکتور" autocomplete="off"><span class="muted catalog-live-status" id="invoice-live-status" aria-live="polite"></span></div>
         <div class="field company"><label>شرکت</label><select name="companyId">${companyOptions}</select></div>
         <div class="field"><label>نوع فاکتور</label><select name="docType">${docTypeOptions}</select></div>
         <div class="field"><label>از تاریخ فاکتور</label><input name="dateFrom" value="${escapeHtml(dateFrom)}" placeholder="1405/01/01" inputmode="numeric"></div>
         <div class="field"><label>تا تاریخ فاکتور</label><input name="dateTo" value="${escapeHtml(dateTo)}" placeholder="1405/12/29" inputmode="numeric"></div>
         <div class="field page-size"><label>تعداد نمایش</label><select name="pageSize">${pageSizeOptions}</select></div>
         <button type="submit">اعمال فیلتر</button>
         <button type="submit" class="button secondary" formaction="/admin/invoices/export" title="خروجی همه نتایج فعلی، نه فقط صفحه جاری">خروجی اکسل</button>
         <button type="submit" class="button secondary" formaction="/admin/invoices/pdf" formtarget="_blank" title="نسخه چاپی همه نتایج فعلی برای ذخیره به‌صورت PDF">خروجی PDF</button>
         <a id="invoice-clear-link" class="button secondary" href="/admin/invoices"${listStateActive ? '' : ' hidden'}>پاک کردن</a>
       </form>
       <div id="invoice-results">
         <div class="table-meta">
           <span class="muted">نمایش ${formatAmount(data.pageSize)} فاکتور در هر صفحه — مجموع ${formatAmount(data.totalCount)} فاکتور — مرتب‌شده بر اساس آخرین ورود به PharmaFlow</span>
         </div>
         <div class="table-wrap"><table><thead><tr>
           ${['تاریخ فاکتور', 'شماره فاکتور', 'شرکت', 'نوع', 'مبلغ قابل پرداخت', 'تاریخ تسویه', 'اقلام', 'ورود به PharmaFlow', 'وضعیت منبع', 'عملیات'].map((header) => `<th>${escapeHtml(header)}</th>`).join('')}
         </tr></thead><tbody>
           ${rows || '<tr><td colspan="10">فاکتوری با این فیلترها یافت نشد.</td></tr>'}
         </tbody></table></div>
         ${pagination}
         <div class="pagination-summary"><span class="muted">صفحه ${formatAmount(data.page)} از ${formatAmount(data.totalPages)}</span></div>
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
       </script>`,
      'invoices',
    );
  }

  @Get('invoices/export')
  async exportInvoices(
    @Query('invoiceNumber') invoiceNumber = '',
    @Query('companyId') companyId = '',
    @Query('docType') docType = '',
    @Query('dateFrom') dateFrom = '',
    @Query('dateTo') dateTo = '',
    @Res() response: Response,
  ) {
    const items = await this.adminService.invoicesExport({
      invoiceNumber,
      companyId,
      docType,
      dateFrom,
      dateTo,
    });

    const file = buildXlsx(
      'فاکتورها',
      [
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
      ],
      items.map((item) => [
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
      ]),
    );

    return this.sendXlsx(response, 'pharmaflow-invoices', file);
  }

  @Get('invoices/pdf')
  @Header('Content-Type', 'text/html; charset=utf-8')
  @Header('Cache-Control', 'no-store, max-age=0')
  async exportInvoicesPdf(
    @Query('invoiceNumber') invoiceNumber = '',
    @Query('companyId') companyId = '',
    @Query('docType') docType = '',
    @Query('dateFrom') dateFrom = '',
    @Query('dateTo') dateTo = '',
  ) {
    const items = await this.adminService.invoicesExport({
      invoiceNumber,
      companyId,
      docType,
      dateFrom,
      dateTo,
    });

    return buildPrintToPdfReport(
      'فاکتورها',
      [
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
      ],
      items.map((item) => [
        item.invoiceDate ?? '',
        item.invoiceNumber ?? '',
        item.company.name,
        this.invoiceDocTypeLabel(item.factorDocType, item.factorDocTypeName),
        item.factorPayablePrice == null
          ? ''
          : formatAmount(item.factorPayablePrice),
        item.settlementDate ?? '',
        item.paymentDays == null ? '' : `${item.paymentDays} روز`,
        item.itemCount,
        item.isDeletedInArsen ? 'حذف‌شده در آرسن' : 'فعال',
        item.description ?? '',
      ]),
      'همه فاکتورهای منطبق با فیلترهای فعلی - بدون محدودیت صفحه‌بندی',
    );
  }

  @Get('invoices/:id')
  @Header('Content-Type', 'text/html; charset=utf-8')
  async invoice(@Param('id') id: string) {
    const item = await this.adminService.invoice(id);
    const grossTotal = item.items.reduce((sum, detail) => {
      const quantity = Number(detail.quantity ?? 0);
      const purchasePrice = Number(detail.purchasePrice ?? 0);
      return sum + quantity * purchasePrice;
    }, 0);
    const discount = Number(item.factorDiscount ?? 0);
    const tax = Number(item.factorTax ?? 0);
    const sourcePayable =
      item.factorPayablePrice == null
        ? null
        : Number(item.factorPayablePrice);
    const payable =
      sourcePayable == null ? grossTotal - discount + tax : sourcePayable;
    const description = String(item.description ?? '').trim();

    const itemRows = item.items
      .map(
        (detail, index) => `<tr>
          <td>${formatAmount(index + 1)}</td>
          <td><strong>${escapeHtml(detail.drugName || `Drug ${String(detail.arsenDrugId ?? '—')}`)}</strong></td>
          <td>${escapeHtml(detail.barcode || '—')}</td>
          <td>${this.amountOrDash(detail.quantity)}</td>
          <td>${detail.packetQuantity == null ? '—' : formatAmount(detail.packetQuantity)}</td>
          <td>${this.amountOrDash(detail.purchasePrice)}</td>
          <td>${this.amountOrDash(detail.salePrice)}</td>
          <td>${this.amountOrDash(detail.rowDiscount)}</td>
          <td>${this.amountOrDash(detail.hasTax)}</td>
          <td>${escapeHtml(detail.batchNumber || '—')}</td>
          <td>${escapeHtml(detail.expireDate || '—')}</td>
        </tr>`,
      )
      .join('');

    return layout(
      `فاکتور ${item.invoiceNumber || item.arsenFactorId}`,
      `<div class="page-title"><h1>جزئیات فاکتور ${escapeHtml(item.invoiceNumber || item.arsenFactorId)}</h1><a class="button secondary" href="/admin/invoices">بازگشت به فاکتورها</a></div>
       <div class="form-card"><div class="grid">
         <div class="field"><label>شرکت</label><div>${escapeHtml(item.company.name)}</div></div>
         <div class="field"><label>نوع</label><div>${escapeHtml(this.invoiceDocTypeLabel(item.factorDocType, item.factorDocTypeName))}</div></div>
         <div class="field"><label>شماره فاکتور</label><div>${escapeHtml(item.invoiceNumber || '—')}</div></div>
         <div class="field"><label>تاریخ فاکتور</label><div>${escapeHtml(item.invoiceDate || '—')}</div></div>
         <div class="field"><label>تاریخ سند آرسن</label><div>${escapeHtml(item.docDate || '—')}</div></div>
         <div class="field"><label>تاریخ تسویه سند</label><div>${escapeHtml(item.settlementDate || '—')}</div></div>
         <div class="field"><label>نوع ثبت</label><div>${escapeHtml(item.factorTypeName || item.factorType || '—')}</div></div>
         <div class="field"><label>گروه</label><div>${escapeHtml(item.factorItemType || '—')}</div></div>
         <div class="field"><label>مهلت پرداخت</label><div>${item.paymentDays == null ? '—' : `${formatAmount(item.paymentDays)} روز`}</div></div>
         <div class="field"><label>جمع فاکتور</label><div>${formatAmount(grossTotal)}</div></div>
         <div class="field"><label>تخفیف</label><div>${this.amountOrDash(item.factorDiscount)}</div></div>
         <div class="field"><label>مالیات</label><div>${this.amountOrDash(item.factorTax)}</div></div>
         <div class="field"><label>باربری</label><div>${this.amountOrDash(item.barbariPrice)}</div></div>
         <div class="field"><label>مبلغ قابل پرداخت</label><div><strong>${formatAmount(payable)}</strong></div></div>
         ${description ? `<div class="field full"><label>توضیحات</label><div>${escapeHtml(description)}</div></div>` : ''}
         <div class="field"><label>تعداد اقلام</label><div>${formatAmount(item.itemCount)}</div></div>
         <div class="field"><label>وضعیت در آرسن</label><div>${item.isDeletedInArsen ? statusBadge('DELETED') : statusBadge('ACTIVE')}</div></div>
         <div class="field"><label>آخرین Save آرسن</label><div>${formatDate(item.arsenSaveDateTime)}</div></div>
         <div class="field"><label>ورود به PharmaFlow</label><div>${formatDate(item.importedAt)}</div></div>
         <div class="field"><label>آخرین Sync منبع</label><div>${formatDate(item.sourceSyncedAt)}</div></div>
         <div class="field full muted system">Arsen Factor ID: ${escapeHtml(item.arsenFactorId)}<br>Arsen BusinessPartner ID: ${escapeHtml(item.arsenBusinessPartnerId)}<br>Source Partner: ${escapeHtml(item.arsenBusinessPartnerName)}<br>UUID: ${escapeHtml(item.id)}</div>
       </div></div>
       <div class="page-title" style="margin-top:22px"><h2>اقلام فاکتور</h2></div>
       <div class="table-wrap"><table><thead><tr>
         ${['ردیف', 'کالا/دارو', 'بارکد', 'تعداد', 'تعداد در بسته', 'قیمت خرید', 'قیمت فروش', 'تخفیف ردیف', 'مالیات', 'بچ', 'انقضا'].map((header) => `<th>${escapeHtml(header)}</th>`).join('')}
       </tr></thead><tbody>${itemRows || '<tr><td colspan="11">اقلام این فاکتور هنوز Sync نشده‌اند.</td></tr>'}</tbody></table></div>`,
      'invoices',
    );
  }

  @Get('companies')
  @Header('Content-Type', 'text/html; charset=utf-8')
  async companies(
    @Query('q') q = '',
    @Query('notice') noticeText?: string,
  ) {
    const items = await this.adminService.companies(q);
    const csrf = this.csrfToken();
    const rows = items
      .map((item) => {
        const blocked =
          item._count.cheques +
            item._count.cashPayments +
            item._count.arsenCompanyMappings +
            item._count.arsenInvoices >
          0
            ? `دارای ${item._count.cheques} چک، ${item._count.cashPayments} واریزی، ${item._count.arsenCompanyMappings} مپینگ آرسن و ${item._count.arsenInvoices} فاکتور آرسن است`
            : undefined;
        return `<tr>
          <td><strong>${escapeHtml(item.name)}</strong></td>
          <td>${escapeHtml(item.nationalId || '—')}</td>
          <td>${escapeHtml(item.bankName || '—')}</td>
          <td>${escapeHtml(item.accountNumber || '—')}</td>
          <td>${escapeHtml(item.cardNumber || '—')}</td>
          <td>${escapeHtml(item.shebaNumber || '—')}</td>
          <td>${item._count.cheques}</td>
          <td>${item._count.cashPayments}</td>
          <td>${item._count.arsenCompanyMappings}</td>
          <td>${item.deletedAt ? statusBadge('DELETED') : item.archivedAt ? statusBadge('ARCHIVED') : statusBadge('ACTIVE')}</td>
          <td>${formatDate(item.updatedAt)}</td>
          <td><div class="row-actions">
            <a class="button secondary" href="/admin/companies/${item.id}/edit">ویرایش</a>
            ${hardDeleteForm(`/admin/companies/${item.id}/hard-delete`, csrf, item.name, blocked)}
          </div></td>
        </tr>`;
      })
      .join('');

    const searchActive = Boolean(String(q ?? '').trim());

    return layout(
      'شرکت‌ها',
      `${notice(noticeText)}
       <div class="toolbar">
         <div class="page-title"><h1>شرکت‌ها</h1></div>
         <form class="search" method="get" action="/admin/companies" id="company-filter-form">
           <input name="q" id="company-live-search" value="${escapeHtml(q)}" placeholder="نام، شناسه، بانک، ویزیتور..." autocomplete="off">
           <span class="muted catalog-live-status" id="company-live-status" aria-live="polite"></span>
           <button type="submit">جستجو</button>
           <button type="submit" class="button secondary" formaction="/admin/companies/export" title="خروجی همه نتایج فعلی">خروجی اکسل</button>
           <button type="submit" class="button secondary" formaction="/admin/companies/pdf" formtarget="_blank" title="نسخه چاپی همه نتایج فعلی برای ذخیره به‌صورت PDF">خروجی PDF</button>
           <a id="company-clear-link" class="button secondary" href="/admin/companies"${searchActive ? '' : ' hidden'}>پاک کردن</a>
         </form>
       </div>
       <div id="company-results">
         <div class="table-wrap"><table><thead><tr>
           ${['نام شرکت', 'شناسه ملی', 'بانک', 'حساب', 'کارت', 'شبا', 'چک', 'واریزی', 'مپینگ آرسن', 'وضعیت', 'آخرین تغییر', 'عملیات'].map((header) => `<th>${escapeHtml(header)}</th>`).join('')}
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
       </script>`,
      'companies',
    );
  }

  @Get('companies/export')
  async exportCompanies(
    @Query('q') q = '',
    @Res() response: Response,
  ) {
    const items = await this.adminService.companies(q);

    const file = buildXlsx(
      'شرکت‌ها',
      [
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
      ],
      items.map((item) => [
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
      ]),
    );

    return this.sendXlsx(response, 'pharmaflow-companies', file);
  }

  @Get('companies/pdf')
  @Header('Content-Type', 'text/html; charset=utf-8')
  @Header('Cache-Control', 'no-store, max-age=0')
  async exportCompaniesPdf(@Query('q') q = '') {
    const items = await this.adminService.companies(q);

    return buildPrintToPdfReport(
      'شرکت‌ها',
      [
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
      ],
      items.map((item) => [
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
      ]),
      'همه شرکت‌های منطبق با جستجوی فعلی',
    );
  }

  @Get('companies/:id/edit')
  @Header('Content-Type', 'text/html; charset=utf-8')
  async editCompany(
    @Param('id') id: string,
    @Query('notice') noticeText?: string,
  ) {
    const item = await this.adminService.company(id);
    const blocked =
      item._count.cheques +
        item._count.cashPayments +
        item._count.arsenCompanyMappings +
        item._count.arsenInvoices >
      0
        ? `ابتدا ${item._count.cheques} چک، ${item._count.cashPayments} واریزی، ${item._count.arsenCompanyMappings} مپینگ آرسن و ${item._count.arsenInvoices} فاکتور آرسن وابسته را حذف کنید.`
        : undefined;

    return layout(
      `ویرایش ${item.name}`,
      `${notice(noticeText)}
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
       ${this.dangerZone(`/admin/companies/${item.id}/hard-delete`, item.name, blocked)}`,
      'companies',
    );
  }

  @Post('companies/:id')
  async updateCompany(
    @Param('id') id: string,
    @Body() body: FormBody,
    @Res() response: Response,
  ) {
    this.verifyCsrf(body._csrf);
    await this.adminService.updateCompany(id, body);
    return response.redirect(303, this.withNotice(`/admin/companies/${id}/edit`, 'تغییرات شرکت ذخیره شد.'));
  }

  @Post('companies/:id/hard-delete')
  async hardDeleteCompany(
    @Param('id') id: string,
    @Body() body: FormBody,
    @Res() response: Response,
  ) {
    this.verifyHardDelete(body);
    await this.adminService.hardDeleteCompany(id);
    return response.redirect(303, this.withNotice('/admin/companies', 'شرکت به‌صورت دائمی حذف شد.'));
  }

  @Get('bank-accounts')
  @Header('Content-Type', 'text/html; charset=utf-8')
  async bankAccounts(
    @Query('q') q = '',
    @Query('notice') noticeText?: string,
  ) {
    const items = await this.adminService.bankAccounts(q);
    const csrf = this.csrfToken();
    const rows = items
      .map((item) => {
        const blocked =
          item._count.cheques + item._count.cashPayments > 0
            ? `دارای ${item._count.cheques} چک و ${item._count.cashPayments} واریزی است`
            : undefined;
        return `<tr>
          <td><strong>${escapeHtml(item.accountTitle || item.bankName)}</strong></td>
          <td>${escapeHtml(item.bankName)}</td>
          <td>${escapeHtml(item.accountHolder || '—')}</td>
          <td>${escapeHtml(item.accountNumber || '—')}</td>
          <td>${escapeHtml(item.cardNumber || '—')}</td>
          <td>${escapeHtml(item.shebaNumber || '—')}</td>
          <td>${item._count.cheques}</td><td>${item._count.cashPayments}</td>
          <td>${item.deletedAt ? statusBadge('DELETED') : item.archivedAt ? statusBadge('ARCHIVED') : statusBadge('ACTIVE')}</td>
          <td>${formatDate(item.updatedAt)}</td>
          <td><div class="row-actions"><a class="button secondary" href="/admin/bank-accounts/${item.id}/edit">ویرایش</a>${hardDeleteForm(`/admin/bank-accounts/${item.id}/hard-delete`, csrf, item.accountTitle || item.bankName, blocked)}</div></td>
        </tr>`;
      })
      .join('');

    return this.listPage(
      'حساب‌های بانکی',
      'accounts',
      q,
      noticeText,
      ['عنوان', 'بانک', 'صاحب حساب', 'حساب', 'کارت', 'شبا', 'چک', 'واریزی', 'وضعیت', 'آخرین تغییر', 'عملیات'],
      rows,
      'بانک، شماره حساب، کارت، شبا...',
    );
  }

  @Get('bank-accounts/:id/edit')
  @Header('Content-Type', 'text/html; charset=utf-8')
  async editBankAccount(
    @Param('id') id: string,
    @Query('notice') noticeText?: string,
  ) {
    const item = await this.adminService.bankAccount(id);
    const label = item.accountTitle || item.bankName;
    const blocked =
      item._count.cheques + item._count.cashPayments > 0
        ? `ابتدا ${item._count.cheques} چک و ${item._count.cashPayments} واریزی وابسته را حذف دائمی کنید.`
        : undefined;

    return layout(
      'ویرایش حساب بانکی',
      `${notice(noticeText)}<div class="page-title"><h1>ویرایش حساب بانکی</h1></div>
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
       ${this.dangerZone(`/admin/bank-accounts/${item.id}/hard-delete`, label, blocked)}`,
      'accounts',
    );
  }

  @Post('bank-accounts/:id')
  async updateBankAccount(
    @Param('id') id: string,
    @Body() body: FormBody,
    @Res() response: Response,
  ) {
    this.verifyCsrf(body._csrf);
    await this.adminService.updateBankAccount(id, body);
    return response.redirect(303, this.withNotice(`/admin/bank-accounts/${id}/edit`, 'تغییرات حساب ذخیره شد.'));
  }

  @Post('bank-accounts/:id/hard-delete')
  async hardDeleteBankAccount(
    @Param('id') id: string,
    @Body() body: FormBody,
    @Res() response: Response,
  ) {
    this.verifyHardDelete(body);
    await this.adminService.hardDeleteBankAccount(id);
    return response.redirect(303, this.withNotice('/admin/bank-accounts', 'حساب بانکی به‌صورت دائمی حذف شد.'));
  }

  @Get('cheques')
  @Header('Content-Type', 'text/html; charset=utf-8')
  async cheques(@Query('q') q = '', @Query('notice') noticeText?: string) {
    const items = await this.adminService.cheques(q);
    const csrf = this.csrfToken();
    const rows = items
      .map(
        (item) => `<tr>
          <td><strong>${escapeHtml(item.chequeNumber)}</strong></td>
          <td>${escapeHtml(item.company.name)}</td>
          <td>${escapeHtml(item.bankAccount.accountTitle || item.bankAccount.bankName)}</td>
          <td>${formatAmount(item.amount)} ریال</td>
          <td>${formatDate(item.dueDate)}</td>
          <td>${statusBadge(item.status)}</td>
          <td>${item.isRegisteredInSayad ? '<span class="badge ok">ثبت‌شده</span>' : '<span class="badge warn">ثبت‌نشده</span>'}</td>
          <td>${item._count.attachments}</td>
          <td>${item.deletedAt ? statusBadge('DELETED') : item.archivedAt ? statusBadge('ARCHIVED') : statusBadge('ACTIVE')}</td>
          <td><div class="row-actions"><a class="button secondary" href="/admin/cheques/${item.id}/edit">ویرایش</a>${hardDeleteForm(`/admin/cheques/${item.id}/hard-delete`, csrf, `چک ${item.chequeNumber}`)}</div></td>
        </tr>`,
      )
      .join('');

    return this.listPage(
      'چک‌ها',
      'cheques',
      q,
      noticeText,
      ['شماره', 'شرکت', 'حساب', 'مبلغ', 'سررسید', 'وضعیت چک', 'صیاد', 'پیوست', 'رکورد', 'عملیات'],
      rows,
      'شماره چک، شرکت، حساب، مبلغ...',
    );
  }

  @Get('cheques/:id/edit')
  @Header('Content-Type', 'text/html; charset=utf-8')
  async editCheque(
    @Param('id') id: string,
    @Query('notice') noticeText?: string,
  ) {
    const data = await this.adminService.cheque(id);
    const item = data.item;
    const companyOptions = data.companies
      .map((company) => this.option(company.id, company.name, item.companyId))
      .join('');
    const accountOptions = data.bankAccounts
      .map((account) => this.option(account.id, account.accountTitle || account.bankName, item.bankAccountId))
      .join('');

    return layout(
      `ویرایش چک ${item.chequeNumber}`,
      `${notice(noticeText)}<div class="page-title"><h1>ویرایش چک</h1></div>
       <form class="form-card" method="post" action="/admin/cheques/${item.id}">${this.csrfInput()}
        <div class="grid">
          ${this.field('شماره چک', 'chequeNumber', item.chequeNumber)}
          ${this.field('مبلغ (ریال)', 'amount', item.amount, 'number')}
          ${this.selectField('شرکت', 'companyId', companyOptions)}
          ${this.selectField('حساب بانکی', 'bankAccountId', accountOptions)}
          ${this.field('تاریخ صدور', 'chequeDate', inputDate(item.chequeDate), 'date')}
          ${this.field('تاریخ سررسید', 'dueDate', inputDate(item.dueDate), 'date')}
          ${this.field('وضعیت چک', 'status', item.status)}
          ${this.field('وضعیت صیاد', 'sayadStatus', item.sayadStatus)}
          ${this.field('شناسه صیاد', 'sayadId', item.sayadId)}
          ${this.booleanSelect('ثبت شده در صیاد', 'isRegisteredInSayad', item.isRegisteredInSayad === true)}
          ${this.textarea('توضیحات', 'description', item.description)}
          ${this.recordState(item.archivedAt, item.deletedAt)}
          <div class="field full muted">تعداد پیوست‌های دیتابیس: ${item.attachments.length}</div>
          ${this.systemInfo(item)}
        </div>${this.saveActions('/admin/cheques')}</form>
       ${this.dangerZone(`/admin/cheques/${item.id}/hard-delete`, `چک ${item.chequeNumber}`)}`,
      'cheques',
    );
  }

  @Post('cheques/:id')
  async updateCheque(@Param('id') id: string, @Body() body: FormBody, @Res() response: Response) {
    this.verifyCsrf(body._csrf);
    await this.adminService.updateCheque(id, body);
    return response.redirect(303, this.withNotice(`/admin/cheques/${id}/edit`, 'تغییرات چک ذخیره شد.'));
  }

  @Post('cheques/:id/hard-delete')
  async hardDeleteCheque(@Param('id') id: string, @Body() body: FormBody, @Res() response: Response) {
    this.verifyHardDelete(body);
    await this.adminService.hardDeleteCheque(id);
    return response.redirect(303, this.withNotice('/admin/cheques', 'چک و وابستگی‌های دیتابیسی آن دائمی حذف شد.'));
  }

  @Get('cash-payments')
  @Header('Content-Type', 'text/html; charset=utf-8')
  async cashPayments(@Query('q') q = '', @Query('notice') noticeText?: string) {
    const items = await this.adminService.cashPayments(q);
    const csrf = this.csrfToken();
    const rows = items
      .map(
        (item) => `<tr>
          <td>${formatDate(item.paymentDate)}</td>
          <td><strong>${escapeHtml(item.company.name)}</strong></td>
          <td>${escapeHtml(item.bankAccount.accountTitle || item.bankAccount.bankName)}</td>
          <td>${formatAmount(item.amount)} ریال</td>
          <td>${escapeHtml(this.paymentMethodLabel(item.paymentMethod))}</td>
          <td>${escapeHtml(item.trackingNumber || '—')}</td>
          <td>${item._count.attachments}</td>
          <td>${item.deletedAt ? statusBadge('DELETED') : item.archivedAt ? statusBadge('ARCHIVED') : statusBadge('ACTIVE')}</td>
          <td><div class="row-actions"><a class="button secondary" href="/admin/cash-payments/${item.id}/edit">ویرایش</a>${hardDeleteForm(`/admin/cash-payments/${item.id}/hard-delete`, csrf, `واریزی ${item.company.name}`)}</div></td>
        </tr>`,
      )
      .join('');

    return this.listPage(
      'واریزی‌ها',
      'cash',
      q,
      noticeText,
      ['تاریخ', 'شرکت', 'حساب', 'مبلغ', 'روش', 'پیگیری', 'پیوست', 'وضعیت', 'عملیات'],
      rows,
      'شرکت، حساب، مبلغ، شماره پیگیری...',
    );
  }

  @Get('cash-payments/:id/edit')
  @Header('Content-Type', 'text/html; charset=utf-8')
  async editCashPayment(@Param('id') id: string, @Query('notice') noticeText?: string) {
    const data = await this.adminService.cashPayment(id);
    const item = data.item;
    const companyOptions = data.companies.map((company) => this.option(company.id, company.name, item.companyId)).join('');
    const accountOptions = data.bankAccounts.map((account) => this.option(account.id, account.accountTitle || account.bankName, item.bankAccountId)).join('');
    const methodOptions = [
      this.option('BANK_DEPOSIT', 'واریز بانکی', item.paymentMethod),
      this.option('POS_PAYMENT', 'پرداخت کارتخوان', item.paymentMethod),
    ].join('');

    return layout(
      'ویرایش واریزی',
      `${notice(noticeText)}<div class="page-title"><h1>ویرایش واریزی</h1></div>
       <form class="form-card" method="post" action="/admin/cash-payments/${item.id}">${this.csrfInput()}
        <div class="grid">
          ${this.field('مبلغ (ریال)', 'amount', item.amount, 'number')}
          ${this.field('تاریخ پرداخت', 'paymentDate', inputDate(item.paymentDate), 'date')}
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
       ${this.dangerZone(`/admin/cash-payments/${item.id}/hard-delete`, `واریزی ${item.company.name}`)}`,
      'cash',
    );
  }

  @Post('cash-payments/:id')
  async updateCashPayment(@Param('id') id: string, @Body() body: FormBody, @Res() response: Response) {
    this.verifyCsrf(body._csrf);
    await this.adminService.updateCashPayment(id, body);
    return response.redirect(303, this.withNotice(`/admin/cash-payments/${id}/edit`, 'تغییرات واریزی ذخیره شد.'));
  }

  @Post('cash-payments/:id/hard-delete')
  async hardDeleteCashPayment(@Param('id') id: string, @Body() body: FormBody, @Res() response: Response) {
    this.verifyHardDelete(body);
    await this.adminService.hardDeleteCashPayment(id);
    return response.redirect(303, this.withNotice('/admin/cash-payments', 'واریزی و وابستگی‌های دیتابیسی آن دائمی حذف شد.'));
  }

  @Get('users')
  @Header('Content-Type', 'text/html; charset=utf-8')
  async users(@Query('q') q = '', @Query('notice') noticeText?: string) {
    const items = await this.adminService.users(q);
    const csrf = this.csrfToken();
    const rows = items
      .map(
        (item) => `<tr>
          <td><strong>${escapeHtml(item.displayName)}</strong></td><td class="system">${escapeHtml(item.username)}</td>
          <td>${escapeHtml(item.role === 'MANAGER' ? 'مدیر' : 'کارمند')}</td>
          <td>${item.isActive ? statusBadge('ACTIVE') : '<span class="badge danger">غیرفعال</span>'}</td>
          <td>${item.managerAppAccess ? '✓' : '—'}</td><td>${item.canCreateOrders ? '✓' : '—'}</td><td>${item.canCreateCheques ? '✓' : '—'}</td><td>${item.canCreateCashPayments ? '✓' : '—'}</td><td>${item.canViewFinancialReports ? '✓' : '—'}</td>
          <td>${item._count.sessions}</td><td>${item._count.pushDevices}</td>
          <td><div class="row-actions"><a class="button secondary" href="/admin/users/${item.id}/edit">ویرایش</a>${hardDeleteForm(`/admin/users/${item.id}/hard-delete`, csrf, item.displayName)}</div></td>
        </tr>`,
      )
      .join('');

    return this.listPage(
      'کاربران',
      'users',
      q,
      noticeText,
      ['نام', 'نام کاربری', 'نقش', 'وضعیت', 'Manager', 'سفارش', 'چک', 'واریزی', 'گزارش مالی', 'Session', 'دستگاه', 'عملیات'],
      rows,
      'نام، نام کاربری، نقش...',
    );
  }

  @Get('users/:id/edit')
  @Header('Content-Type', 'text/html; charset=utf-8')
  async editUser(@Param('id') id: string, @Query('notice') noticeText?: string) {
    const item = await this.adminService.user(id);
    const roleOptions = [this.option('MANAGER', 'مدیر', item.role), this.option('STAFF', 'کارمند', item.role)].join('');
    return layout(
      `ویرایش ${item.displayName}`,
      `${notice(noticeText)}<div class="page-title"><h1>ویرایش کاربر</h1></div>
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
       ${this.dangerZone(`/admin/users/${item.id}/hard-delete`, item.displayName)}`,
      'users',
    );
  }

  @Post('users/:id')
  async updateUser(@Param('id') id: string, @Body() body: FormBody, @Res() response: Response) {
    this.verifyCsrf(body._csrf);
    await this.adminService.updateUser(id, body);
    return response.redirect(303, this.withNotice(`/admin/users/${id}/edit`, 'تغییرات کاربر ذخیره شد.'));
  }

  @Post('users/:id/hard-delete')
  async hardDeleteUser(@Param('id') id: string, @Body() body: FormBody, @Res() response: Response) {
    this.verifyHardDelete(body);
    await this.adminService.hardDeleteUser(id);
    return response.redirect(303, this.withNotice('/admin/users', 'کاربر، Sessionها و دستگاه‌هایش دائمی حذف شدند.'));
  }

  @Get('orders')
  @Header('Content-Type', 'text/html; charset=utf-8')
  async orders(
    @Query('q') q = '',
    @Query('status') status = '',
    @Query('notice') noticeText?: string,
  ) {
    const items = await this.adminService.orders(q, status);
    const csrf = this.csrfToken();
    const rows = items
      .map(
        (item) => `<tr>
          <td><strong>${escapeHtml(item.itemText)}</strong></td>
          <td>${escapeHtml(item.category === 'DRUG' ? 'دارو' : 'کالا')}</td>
          <td>${item.requestedQuantity ?? '—'}</td><td>${item.orderedQuantity ?? '—'}</td>
          <td>${escapeHtml(item.assignedCompany?.name || item.suggestedCompanyText || '—')}</td>
          <td>${escapeHtml(item.requestedByName)}</td><td>${statusBadge(item.status)}</td>
          <td>${item.possibleDuplicate ? '<span class="badge warn">مشابه</span>' : '—'}</td>
          <td>${formatDate(item.createdAt)}</td>
          <td><div class="row-actions"><a class="button secondary" href="/admin/orders/${item.id}/edit">ویرایش</a>${hardDeleteForm(`/admin/orders/${item.id}/hard-delete`, csrf, item.itemText)}</div></td>
        </tr>`,
      )
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

    return this.listPage(
      'سفارشات',
      'orders',
      q,
      noticeText,
      ['آیتم', 'گروه', 'درخواستی', 'سفارش‌شده', 'شرکت', 'درخواست‌کننده', 'وضعیت', 'مشابه', 'ثبت', 'عملیات'],
      rows,
      'نام آیتم، شرکت، کاربر، توضیحات...',
      extraFilter,
    );
  }

  @Get('orders/:id/edit')
  @Header('Content-Type', 'text/html; charset=utf-8')
  async editOrder(@Param('id') id: string, @Query('notice') noticeText?: string) {
    const data = await this.adminService.order(id);
    const item = data.item;
    const companyOptions = [this.option('', 'بدون شرکت', item.assignedCompanyId), ...data.companies.map((company) => this.option(company.id, company.name, item.assignedCompanyId))].join('');
    const categoryOptions = [this.option('DRUG', 'دارو', item.category), this.option('GOODS', 'کالا', item.category)].join('');
    const statusOptions = ['PENDING', 'ORDERED', 'RECEIVED', 'CANCELED', 'DELETED'].map((value) => this.option(value, this.orderStatusLabel(value), item.status)).join('');

    return layout(
      `ویرایش ${item.itemText}`,
      `${notice(noticeText)}<div class="page-title"><h1>ویرایش سفارش</h1></div>
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
          ${this.field('زمان سفارش', 'orderedAt', inputDateTime(item.orderedAt), 'datetime-local')}
          ${this.field('زمان دریافت', 'receivedAt', inputDateTime(item.receivedAt), 'datetime-local')}
          ${this.field('زمان لغو', 'canceledAt', inputDateTime(item.canceledAt), 'datetime-local')}
          ${this.field('زمان حذف نرم', 'deletedAt', inputDateTime(item.deletedAt), 'datetime-local')}
          ${this.textarea('یادداشت', 'notes', item.notes)}
          <div class="field full muted">عکس سفارش: ${item.photoStorageKey ? 'موجود' : 'ندارد'} — UUIDهای کاربران برای حفظ تاریخچه تغییر نمی‌کنند.</div>
          ${this.systemInfo(item)}
        </div>${this.saveActions('/admin/orders')}</form>
       ${this.dangerZone(`/admin/orders/${item.id}/hard-delete`, item.itemText)}`,
      'orders',
    );
  }

  @Post('orders/:id')
  async updateOrder(@Param('id') id: string, @Body() body: FormBody, @Res() response: Response) {
    this.verifyCsrf(body._csrf);
    await this.adminService.updateOrder(id, body);
    return response.redirect(303, this.withNotice(`/admin/orders/${id}/edit`, 'تغییرات سفارش ذخیره شد.'));
  }

  @Post('orders/:id/hard-delete')
  async hardDeleteOrder(@Param('id') id: string, @Body() body: FormBody, @Res() response: Response) {
    this.verifyHardDelete(body);
    await this.adminService.hardDeleteOrder(id);
    return response.redirect(303, this.withNotice('/admin/orders', 'سفارش به‌صورت دائمی حذف شد.'));
  }

  @Get('audit-logs')
  @Header('Content-Type', 'text/html; charset=utf-8')
  async auditLogs(@Query('q') q = '', @Query('notice') noticeText?: string) {
    const items = await this.adminService.auditLogs(q);
    const csrf = this.csrfToken();
    const rows = items
      .map((item) => {
        const beforeText = item.beforeData == null ? '—' : JSON.stringify(item.beforeData, null, 2);
        const afterText = item.afterData == null ? '—' : JSON.stringify(item.afterData, null, 2);
        return `<tr>
          <td>${formatDate(item.createdAt)}</td><td><strong>${escapeHtml(item.actorDisplayName || '—')}</strong></td>
          <td>${escapeHtml(item.source)}</td><td>${escapeHtml(item.action)}</td><td>${escapeHtml(item.entityType)}</td>
          <td class="system">${escapeHtml(item.entityId || '—')}</td>
          <td><details><summary>قبل</summary><pre class="audit-json">${escapeHtml(beforeText)}</pre></details></td>
          <td><details><summary>بعد</summary><pre class="audit-json">${escapeHtml(afterText)}</pre></details></td>
          <td>${hardDeleteForm(`/admin/audit-logs/${item.id}/hard-delete`, csrf, `رویداد ${item.action}`)}</td>
        </tr>`;
      })
      .join('');

    return this.listPage(
      'تاریخچه تغییرات',
      'audit',
      q,
      noticeText,
      ['زمان', 'کاربر', 'منبع', 'عملیات', 'نوع', 'UUID', 'قبل', 'بعد', 'حذف'],
      rows,
      'کاربر، عملیات، نوع، UUID...',
    );
  }

  @Post('audit-logs/:id/hard-delete')
  async hardDeleteAuditLog(@Param('id') id: string, @Body() body: FormBody, @Res() response: Response) {
    this.verifyHardDelete(body);
    await this.adminService.hardDeleteAuditLog(id);
    return response.redirect(303, this.withNotice('/admin/audit-logs', 'رویداد انتخاب‌شده دائمی حذف و عملیات حذف ثبت شد.'));
  }

  private listPage(
    title: string,
    active: string,
    query: string,
    noticeText: string | undefined,
    headers: string[],
    rows: string,
    placeholder: string,
    extraFilter = '',
  ): string {
    return layout(
      title,
      `${notice(noticeText)}<div class="toolbar"><div class="page-title"><h1>${escapeHtml(title)}</h1></div>
       <form class="search" method="get"><input name="q" value="${escapeHtml(query)}" placeholder="${escapeHtml(placeholder)}">${extraFilter}<button>جستجو</button></form></div>
       <div class="table-wrap"><table><thead><tr>${headers.map((header) => `<th>${escapeHtml(header)}</th>`).join('')}</tr></thead>
       <tbody>${rows || `<tr><td colspan="${headers.length}">رکوردی یافت نشد.</td></tr>`}</tbody></table></div>`,
      active,
    );
  }

  private field(label: string, name: string, value: unknown, type = 'text'): string {
    return `<div class="field"><label>${escapeHtml(label)}</label><input type="${escapeHtml(type)}" name="${escapeHtml(name)}" value="${escapeHtml(value ?? '')}"></div>`;
  }

  private textarea(label: string, name: string, value: unknown): string {
    return `<div class="field full"><label>${escapeHtml(label)}</label><textarea name="${escapeHtml(name)}">${escapeHtml(value ?? '')}</textarea></div>`;
  }

  private selectField(label: string, name: string, options: string): string {
    return `<div class="field"><label>${escapeHtml(label)}</label><select name="${escapeHtml(name)}">${options}</select></div>`;
  }

  private option(value: string, label: string, selected: string | null | undefined): string {
    return `<option value="${escapeHtml(value)}" ${value === String(selected ?? '') ? 'selected' : ''}>${escapeHtml(label)}</option>`;
  }

  private checkbox(label: string, name: string, checked: boolean): string {
    return `<div class="field"><label class="check-row"><input type="checkbox" name="${escapeHtml(name)}" value="1" ${checked ? 'checked' : ''}>${escapeHtml(label)}</label></div>`;
  }

  private booleanSelect(label: string, name: string, checked: boolean, yes = 'بله', no = 'خیر'): string {
    return this.selectField(label, name, `${this.option('1', yes, checked ? '1' : '0')}${this.option('0', no, checked ? '1' : '0')}`);
  }

  private recordState(archivedAt: Date | null, deletedAt: Date | null): string {
    return `${this.booleanSelect('آرشیو', 'archived', archivedAt != null, 'آرشیوشده', 'فعال')}${this.booleanSelect('حذف نرم', 'softDeleted', deletedAt != null, 'حذف‌شده', 'موجود')}`;
  }

  private systemInfo(item: { id: string; createdAt: Date; updatedAt: Date }): string {
    return `<div class="field full muted system">UUID: ${escapeHtml(item.id)}<br>Created: ${formatDate(item.createdAt)}<br>Updated: ${formatDate(item.updatedAt)}</div>`;
  }

  private saveActions(backUrl: string): string {
    return `<div class="actions"><button type="submit">ذخیره تغییرات</button><a class="button secondary" href="${escapeHtml(backUrl)}">بازگشت</a></div>`;
  }

  private dangerZone(action: string, label: string, blocked?: string): string {
    return `<div class="danger-zone"><h2>منطقه خطر</h2><p>حذف دائمی قابل بازگشت نیست و پس از تأیید با عبارت DELETE انجام می‌شود.</p>${blocked ? `<div class="dependency">${escapeHtml(blocked)}</div>` : ''}${hardDeleteForm(action, this.csrfToken(), label, blocked)}</div>`;
  }

  private sendXlsx(response: Response, baseName: string, file: Buffer): void {
    const stamp = new Date().toISOString().replace(/[-:]/g, '').slice(0, 13);
    const fileName = `${baseName}-${stamp}.xlsx`;
    response.setHeader(
      'Content-Type',
      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    );
    response.setHeader(
      'Content-Disposition',
      `attachment; filename="${fileName}"`,
    );
    response.setHeader('Cache-Control', 'no-store, max-age=0');
    response.setHeader('X-Content-Type-Options', 'nosniff');
    response.setHeader('Content-Length', String(file.length));
    response.status(200).send(file);
  }

  private excelNumber(value: unknown): number | string {
    if (value == null || String(value).trim() === '') {
      return '';
    }
    const text = String(value);
    const number = Number(text);
    return Number.isFinite(number) && Math.abs(number) <= Number.MAX_SAFE_INTEGER
      ? number
      : text;
  }

  private excelDateTime(value: Date | string | null | undefined): string {
    if (!value) {
      return '';
    }
    const date = new Date(value);
    return Number.isNaN(date.getTime())
      ? String(value)
      : date.toISOString().replace('T', ' ').slice(0, 19);
  }

  private amountOrDash(value: unknown): string {
    return value == null || String(value).trim() === '' ? '—' : formatAmount(value);
  }

  private invoiceDocTypeLabel(
    value: number,
    sourceLabel?: string | null,
  ): string {
    if (value === 1) {
      return 'خرید';
    }
    if (value === 2) {
      return 'برگشت خرید';
    }
    return sourceLabel || String(value);
  }

  private catalogCategoryBadge(value: string): string {
    const category = String(value ?? '').toUpperCase();
    if (category === 'DRUG') {
      return '<span class="badge ok">دارو</span>';
    }
    if (category === 'GOODS') {
      return '<span class="badge">کالا</span>';
    }
    return `<span class="badge">${escapeHtml(value || '—')}</span>`;
  }

  private catalogListUrl(filters: {
    q?: string;
    category?: string;
    active?: string;
    shape?: string;
    sort?: string;
    page?: string;
    pageSize?: string;
  }): string {
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

  private invoiceListUrl(filters: {
    invoiceNumber?: string;
    companyId?: string;
    docType?: string;
    dateFrom?: string;
    dateTo?: string;
    page?: string;
    pageSize?: string;
  }): string {
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

  private paymentMethodLabel(value: string): string {
    return value === 'BANK_DEPOSIT' ? 'واریز بانکی' : value === 'POS_PAYMENT' ? 'پرداخت کارتخوان' : value;
  }

  private orderStatusLabel(value: string): string {
    return ({ PENDING: 'در انتظار', ORDERED: 'سفارش‌شده', RECEIVED: 'دریافت‌شده', CANCELED: 'لغوشده', DELETED: 'حذف‌شده' } as Record<string, string>)[value] ?? value;
  }

  private withNotice(path: string, text: string): string {
    return `${path}${path.includes('?') ? '&' : '?'}notice=${encodeURIComponent(text)}`;
  }

  private csrfInput(): string {
    return `<input type="hidden" name="_csrf" value="${this.csrfToken()}">`;
  }

  private csrfToken(): string {
    return createHmac('sha256', process.env.ADMIN_PASSWORD ?? '')
      .update('pharmaflow-admin-csrf-v1')
      .digest('hex');
  }

  private verifyCsrf(value: string | undefined): void {
    const expected = Buffer.from(this.csrfToken());
    const received = Buffer.from(String(value ?? ''));
    if (expected.length !== received.length || !timingSafeEqual(expected, received)) {
      throw new ForbiddenException('Invalid CSRF token.');
    }
  }

  private verifyHardDelete(body: FormBody): void {
    this.verifyCsrf(body._csrf);
    if (body._confirmation !== 'DELETE') {
      throw new ForbiddenException('Hard delete confirmation is invalid.');
    }
  }
}
