import {
  Body,
  Controller,
  Get,
  Header,
  Param,
  Post,
  Query,
  Res,
} from '@nestjs/common';
import type { Response } from 'express';
import { createHmac, timingSafeEqual } from 'node:crypto';

import { AdminService } from './admin.service';
import { AuditLogService } from '../audit/audit-log.service';
import {
  escapeHtml,
  formatAmount,
  formatDate,
  inputDate,
  layout,
} from './admin-view';

type FormBody = Record<string, string | undefined>;

@Controller('admin')
export class AdminController {
  constructor(
    private readonly adminService: AdminService,
    private readonly auditLogService: AuditLogService,
  ) {}

  @Get()
  @Header('Content-Type', 'text/html; charset=utf-8')
  async dashboard() {
    const data = await this.adminService.dashboard();

    return layout(
      'داشبورد',
      `
      <h1>داشبورد سرور</h1>

      <div class="cards">
        <div class="card">
          <div class="muted">شرکت‌ها</div>
          <div class="metric">${data.companies.length}</div>
        </div>

        <div class="card">
          <div class="muted">حساب‌های بانکی</div>
          <div class="metric">${data.bankAccounts.length}</div>
        </div>

        <div class="card">
          <div class="muted">چک‌ها</div>
          <div class="metric">${data.cheques.length}</div>
        </div>
      </div>
      `,
      'dashboard',
    );
  }

  @Get('audit-logs')
  @Header('Content-Type', 'text/html; charset=utf-8')
  async auditLogs(@Query('q') q = '') {
    const items = await this.auditLogService.findRecent(q);

    const rows = items
      .map((item) => {
        const beforeText =
          item.beforeData == null
            ? '—'
            : JSON.stringify(item.beforeData, null, 2);

        const afterText =
          item.afterData == null
            ? '—'
            : JSON.stringify(item.afterData, null, 2);

        return `
          <tr>
            <td>${formatDate(item.createdAt)}</td>
            <td><strong>${escapeHtml(item.actorDisplayName || '—')}</strong></td>
            <td>${escapeHtml(item.source)}</td>
            <td>${escapeHtml(item.action)}</td>
            <td>${escapeHtml(item.entityType)}</td>
            <td class="system">${escapeHtml(item.entityId || '—')}</td>
            <td>${escapeHtml(item.deviceId || '—')}</td>
            <td>
              <details>
                <summary>قبل</summary>
                <pre class="audit-json">${escapeHtml(beforeText)}</pre>
              </details>
            </td>
            <td>
              <details>
                <summary>بعد</summary>
                <pre class="audit-json">${escapeHtml(afterText)}</pre>
              </details>
            </td>
          </tr>
        `;
      })
      .join('');

    return layout(
      'تاریخچه تغییرات',
      `
      <div class="toolbar">
        <h1>تاریخچه تغییرات</h1>

        <form class="search" method="get">
          <input
            name="q"
            value="${escapeHtml(q)}"
            placeholder="کاربر، منبع، عملیات، UUID..."
          >
          <button>جستجو</button>
        </form>
      </div>

      <div class="table-wrap">
        <table>
          <thead>
            <tr>
              <th>زمان</th>
              <th>کاربر</th>
              <th>منبع</th>
              <th>عملیات</th>
              <th>نوع</th>
              <th>UUID</th>
              <th>دستگاه</th>
              <th>قبل</th>
              <th>بعد</th>
            </tr>
          </thead>

          <tbody>
            ${
              rows || '<tr><td colspan="9">هنوز رویدادی ثبت نشده است.</td></tr>'
            }
          </tbody>
        </table>
      </div>
      `,
      'audit',
    );
  }
  @Get('companies')
  @Header('Content-Type', 'text/html; charset=utf-8')
  async companies(@Query('q') q = '') {
    const items = await this.adminService.companies(q);

    const rows = items
      .map(
        (item) => `
        <tr>
          <td><strong>${escapeHtml(item.name)}</strong></td>
          <td>${escapeHtml(item.nationalId || '—')}</td>
          <td>${escapeHtml(item.bankName || '—')}</td>

          <td>
            ${escapeHtml(item.accountNumber || '—')}
            ${
              item.accountNumber
                ? `<button class="copy" type="button" data-copy="${escapeHtml(item.accountNumber)}">⧉</button>`
                : ''
            }
          </td>

          <td>
            ${escapeHtml(item.cardNumber || '—')}
            ${
              item.cardNumber
                ? `<button class="copy" type="button" data-copy="${escapeHtml(item.cardNumber)}">⧉</button>`
                : ''
            }
          </td>

          <td>
            ${escapeHtml(item.shebaNumber || '—')}
            ${
              item.shebaNumber
                ? `<button class="copy" type="button" data-copy="${escapeHtml(String(item.shebaNumber).replace(/^IR/i, ''))}">⧉</button>`
                : ''
            }
          </td>

          <td>${formatDate(item.updatedAt)}</td>

          <td>
            <a class="button secondary" href="/admin/companies/${item.id}/edit">
              ویرایش
            </a>
          </td>
        </tr>
      `,
      )
      .join('');

    return layout(
      'شرکت‌ها',
      `
      <div class="toolbar">
        <h1>شرکت‌ها</h1>

        <form class="search" method="get">
          <input name="q" value="${escapeHtml(q)}" placeholder="جستجو در اطلاعات شرکت...">
          <button>جستجو</button>
        </form>
      </div>

      <div class="table-wrap">
        <table>
          <thead>
            <tr>
              <th>نام شرکت</th>
              <th>شناسه ملی</th>
              <th>بانک</th>
              <th>شماره حساب</th>
              <th>شماره کارت</th>
              <th>شبا</th>
              <th>آخرین تغییر</th>
              <th></th>
            </tr>
          </thead>
          <tbody>
            ${rows || '<tr><td colspan="8">رکوردی یافت نشد.</td></tr>'}
          </tbody>
        </table>
      </div>
      `,
      'companies',
    );
  }

  @Get('companies/:id/edit')
  @Header('Content-Type', 'text/html; charset=utf-8')
  async editCompany(@Param('id') id: string) {
    const item = await this.adminService.company(id);

    return layout(
      `ویرایش ${item.name}`,
      `
      <h1>ویرایش شرکت</h1>

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

          <div class="field full">
            <label>توضیحات</label>
            <textarea name="notes">${escapeHtml(item.notes || '')}</textarea>
          </div>

          ${this.archiveField(item.archivedAt)}

          <div class="field full muted system">
            UUID: ${escapeHtml(item.id)}
            <br>
            Created: ${formatDate(item.createdAt)}
            <br>
            Updated: ${formatDate(item.updatedAt)}
          </div>
        </div>

        <div class="actions">
          <button type="submit">ذخیره تغییرات</button>
          <a class="button secondary" href="/admin/companies">انصراف</a>
        </div>
      </form>
      `,
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

    console.log(
      JSON.stringify({
        event: 'admin.company.update',
        entityId: id,
        timestamp: new Date().toISOString(),
      }),
    );

    return response.redirect(303, `/admin/companies/${id}/edit`);
  }

  @Get('bank-accounts')
  @Header('Content-Type', 'text/html; charset=utf-8')
  async bankAccounts(@Query('q') q = '') {
    const items = await this.adminService.bankAccounts(q);

    const rows = items
      .map(
        (item) => `
        <tr>
          <td><strong>${escapeHtml(item.accountTitle || '—')}</strong></td>
          <td>${escapeHtml(item.bankName)}</td>
          <td>${escapeHtml(item.accountHolder || '—')}</td>
          <td>${escapeHtml(item.accountNumber || '—')}</td>
          <td>${escapeHtml(item.cardNumber || '—')}</td>
          <td>${escapeHtml(item.shebaNumber || '—')}</td>
          <td>${formatDate(item.updatedAt)}</td>
          <td>
            <a class="button secondary" href="/admin/bank-accounts/${item.id}/edit">
              ویرایش
            </a>
          </td>
        </tr>
      `,
      )
      .join('');

    return layout(
      'حساب‌های بانکی',
      `
      <div class="toolbar">
        <h1>حساب‌های بانکی</h1>

        <form class="search" method="get">
          <input name="q" value="${escapeHtml(q)}" placeholder="جستجو...">
          <button>جستجو</button>
        </form>
      </div>

      <div class="table-wrap">
        <table>
          <thead>
            <tr>
              <th>عنوان حساب</th>
              <th>بانک</th>
              <th>صاحب حساب</th>
              <th>شماره حساب</th>
              <th>شماره کارت</th>
              <th>شبا</th>
              <th>آخرین تغییر</th>
              <th></th>
            </tr>
          </thead>
          <tbody>
            ${rows || '<tr><td colspan="8">رکوردی یافت نشد.</td></tr>'}
          </tbody>
        </table>
      </div>
      `,
      'accounts',
    );
  }

  @Get('bank-accounts/:id/edit')
  @Header('Content-Type', 'text/html; charset=utf-8')
  async editBankAccount(@Param('id') id: string) {
    const item = await this.adminService.bankAccount(id);

    return layout(
      'ویرایش حساب بانکی',
      `
      <h1>ویرایش حساب بانکی</h1>

      <form class="form-card" method="post" action="/admin/bank-accounts/${item.id}">
        ${this.csrfInput()}

        <div class="grid">
          ${this.field('نام بانک', 'bankName', item.bankName)}
          ${this.field('عنوان حساب', 'accountTitle', item.accountTitle)}
          ${this.field('صاحب حساب', 'accountHolder', item.accountHolder)}
          ${this.field('شماره حساب', 'accountNumber', item.accountNumber)}
          ${this.field('شماره کارت', 'cardNumber', item.cardNumber)}
          ${this.field('شماره شبا', 'shebaNumber', item.shebaNumber)}

          <div class="field full">
            <label>توضیحات</label>
            <textarea name="notes">${escapeHtml(item.notes || '')}</textarea>
          </div>

          ${this.archiveField(item.archivedAt)}

          <div class="field full muted system">
            UUID: ${escapeHtml(item.id)}
            <br>
            Created: ${formatDate(item.createdAt)}
            <br>
            Updated: ${formatDate(item.updatedAt)}
          </div>
        </div>

        <div class="actions">
          <button>ذخیره تغییرات</button>
          <a class="button secondary" href="/admin/bank-accounts">انصراف</a>
        </div>
      </form>
      `,
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

    console.log(
      JSON.stringify({
        event: 'admin.bank_account.update',
        entityId: id,
        timestamp: new Date().toISOString(),
      }),
    );

    return response.redirect(303, `/admin/bank-accounts/${id}/edit`);
  }

  @Get('cheques')
  @Header('Content-Type', 'text/html; charset=utf-8')
  async cheques(@Query('q') q = '') {
    const items = await this.adminService.cheques(q);

    const rows = items
      .map(
        (item) => `
        <tr>
          <td><strong>${escapeHtml(item.chequeNumber)}</strong></td>
          <td>${escapeHtml(item.companyName)}</td>
          <td>${escapeHtml(item.bankAccountName)}</td>
          <td>${formatAmount(item.amount)} ریال</td>
          <td>${formatDate(item.dueDate)}</td>
          <td>${escapeHtml(item.status || '—')}</td>
          <td>
            ${
              item.isRegisteredInSayad
                ? '<span class="badge ok">ثبت شده</span>'
                : '<span class="badge warn">ثبت نشده</span>'
            }
          </td>
          <td>${formatDate(item.updatedAt)}</td>
          <td>
            <a class="button secondary" href="/admin/cheques/${item.id}/edit">
              ویرایش
            </a>
          </td>
        </tr>
      `,
      )
      .join('');

    return layout(
      'چک‌ها',
      `
      <div class="toolbar">
        <h1>چک‌ها</h1>

        <form class="search" method="get">
          <input name="q" value="${escapeHtml(q)}" placeholder="شماره چک، شرکت، حساب...">
          <button>جستجو</button>
        </form>
      </div>

      <div class="table-wrap">
        <table>
          <thead>
            <tr>
              <th>شماره چک</th>
              <th>شرکت</th>
              <th>حساب</th>
              <th>مبلغ</th>
              <th>سررسید</th>
              <th>وضعیت</th>
              <th>صیاد</th>
              <th>آخرین تغییر</th>
              <th></th>
            </tr>
          </thead>

          <tbody>
            ${rows || '<tr><td colspan="9">رکوردی یافت نشد.</td></tr>'}
          </tbody>
        </table>
      </div>
      `,
      'cheques',
    );
  }

  @Get('cheques/:id/edit')
  @Header('Content-Type', 'text/html; charset=utf-8')
  async editCheque(@Param('id') id: string) {
    const data = await this.adminService.cheque(id);
    const item = data.item;

    const companyOptions = data.companies
      .map(
        (company) =>
          `<option value="${company.id}" ${
            company.id === item.companyId ? 'selected' : ''
          }>${escapeHtml(company.name)}</option>`,
      )
      .join('');

    const accountOptions = data.bankAccounts
      .map(
        (account) =>
          `<option value="${account.id}" ${
            account.id === item.bankAccountId ? 'selected' : ''
          }>${escapeHtml(account.accountTitle || account.bankName)}</option>`,
      )
      .join('');

    return layout(
      `ویرایش چک ${item.chequeNumber}`,
      `
      <h1>ویرایش چک</h1>

      <form class="form-card" method="post" action="/admin/cheques/${item.id}">
        ${this.csrfInput()}

        <div class="grid">
          ${this.field('شماره چک', 'chequeNumber', item.chequeNumber)}
          ${this.field('مبلغ (ریال)', 'amount', item.amount)}

          <div class="field">
            <label>شرکت</label>
            <select name="companyId">${companyOptions}</select>
          </div>

          <div class="field">
            <label>حساب بانکی</label>
            <select name="bankAccountId">${accountOptions}</select>
          </div>

          ${this.field('تاریخ صدور', 'chequeDate', inputDate(item.chequeDate), 'date')}
          ${this.field('تاریخ سررسید', 'dueDate', inputDate(item.dueDate), 'date')}
          ${this.field('وضعیت', 'status', item.status)}
          ${this.field('وضعیت صیاد', 'sayadStatus', item.sayadStatus)}
          ${this.field('شناسه صیاد', 'sayadId', item.sayadId)}

          <div class="field">
            <label>ثبت شده در صیاد</label>
            <select name="isRegisteredInSayad">
              <option value="0" ${!item.isRegisteredInSayad ? 'selected' : ''}>خیر</option>
              <option value="1" ${item.isRegisteredInSayad ? 'selected' : ''}>بله</option>
            </select>
          </div>

          <div class="field full">
            <label>توضیحات</label>
            <textarea name="description">${escapeHtml(item.description || '')}</textarea>
          </div>

          ${
            item.imageData
              ? `
                <div class="field full">
                  <label>تصویر چک ذخیره‌شده روی سرور</label>
                  <img
                    src="data:image/jpeg;base64,${escapeHtml(item.imageData)}"
                    alt="تصویر چک"
                    style="max-width:420px;width:100%;border-radius:10px;border:1px solid #ddd"
                  >
                </div>
              `
              : ''
          }

          ${this.archiveField(item.archivedAt)}

          <div class="field full muted system">
            UUID: ${escapeHtml(item.id)}
            <br>
            Created: ${formatDate(item.createdAt)}
            <br>
            Updated: ${formatDate(item.updatedAt)}
          </div>
        </div>

        <div class="actions">
          <button>ذخیره تغییرات</button>
          <a class="button secondary" href="/admin/cheques">انصراف</a>
        </div>
      </form>
      `,
      'cheques',
    );
  }

  @Post('cheques/:id')
  async updateCheque(
    @Param('id') id: string,
    @Body() body: FormBody,
    @Res() response: Response,
  ) {
    this.verifyCsrf(body._csrf);
    await this.adminService.updateCheque(id, body);

    console.log(
      JSON.stringify({
        event: 'admin.cheque.update',
        entityId: id,
        timestamp: new Date().toISOString(),
      }),
    );

    return response.redirect(303, `/admin/cheques/${id}/edit`);
  }

  private field(
    label: string,
    name: string,
    value: unknown,
    type = 'text',
  ): string {
    return `
      <div class="field">
        <label>${escapeHtml(label)}</label>
        <input
          type="${escapeHtml(type)}"
          name="${escapeHtml(name)}"
          value="${escapeHtml(value ?? '')}"
        >
      </div>
    `;
  }

  private archiveField(archivedAt: Date | null): string {
    return `
      <div class="field">
        <label>وضعیت</label>
        <select name="archived">
          <option value="0" ${archivedAt == null ? 'selected' : ''}>فعال</option>
          <option value="1" ${archivedAt != null ? 'selected' : ''}>آرشیو شده</option>
        </select>
      </div>
    `;
  }

  private csrfInput(): string {
    return `<input type="hidden" name="_csrf" value="${this.csrfToken()}">`;
  }

  private csrfToken(): string {
    const password = process.env.ADMIN_PASSWORD ?? '';

    return createHmac('sha256', password)
      .update('pharmaflow-admin-csrf-v1')
      .digest('hex');
  }

  private verifyCsrf(value: string | undefined): void {
    const expected = Buffer.from(this.csrfToken());
    const received = Buffer.from(String(value ?? ''));

    if (
      expected.length !== received.length ||
      !timingSafeEqual(expected, received)
    ) {
      throw new Error('Invalid CSRF token');
    }
  }
}
