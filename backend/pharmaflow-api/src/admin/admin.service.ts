import { Injectable, NotFoundException } from '@nestjs/common';

import { CompaniesService } from '../companies/companies.service';
import { BankAccountsService } from '../bank-accounts/bank-accounts.service';
import { ChequesService } from '../cheques/cheques.service';

type FormBody = Record<string, string | undefined>;

@Injectable()
export class AdminService {
  constructor(
    private readonly companiesService: CompaniesService,
    private readonly bankAccountsService: BankAccountsService,
    private readonly chequesService: ChequesService,
  ) {}

  async dashboard() {
    const [companies, bankAccounts, cheques] = await Promise.all([
      this.companiesService.findAll(),
      this.bankAccountsService.findAll(),
      this.chequesService.findAll(),
    ]);

    return {
      companies,
      bankAccounts,
      cheques,
    };
  }

  async companies(query = '') {
    const companies = await this.companiesService.findAll();
    const q = query.trim().toLowerCase();

    if (!q) {
      return companies;
    }

    return companies.filter((item) =>
      [
        item.name,
        item.nationalId,
        item.economicCode,
        item.bankName,
        item.accountNumber,
        item.cardNumber,
        item.shebaNumber,
        item.visitorName,
        item.visitorPhone,
        item.accountantName,
        item.accountantPhone,
      ].some((value) =>
        String(value ?? '')
          .toLowerCase()
          .includes(q),
      ),
    );
  }

  async company(id: string) {
    const item = await this.companiesService.findOne(id);

    if (!item) {
      throw new NotFoundException('Company not found');
    }

    return item;
  }

  async updateCompany(id: string, body: FormBody) {
    return this.companiesService.update(id, {
      name: this.required(body.name),
      nationalId: this.nullable(body.nationalId),
      economicCode: this.nullable(body.economicCode),
      bankName: this.nullable(body.bankName),
      accountNumber: this.nullable(body.accountNumber),
      cardNumber: this.nullable(body.cardNumber),
      shebaNumber: this.nullable(body.shebaNumber),
      notes: this.nullable(body.notes),
      visitorName: this.nullable(body.visitorName),
      visitorPhone: this.nullable(body.visitorPhone),
      accountantName: this.nullable(body.accountantName),
      accountantPhone: this.nullable(body.accountantPhone),
      archivedAt: body.archived === '1' ? new Date().toISOString() : null,
    });
  }

  async bankAccounts(query = '') {
    const items = await this.bankAccountsService.findAll();
    const q = query.trim().toLowerCase();

    if (!q) {
      return items;
    }

    return items.filter((item) =>
      [
        item.bankName,
        item.accountTitle,
        item.accountHolder,
        item.accountNumber,
        item.cardNumber,
        item.shebaNumber,
        item.notes,
      ].some((value) =>
        String(value ?? '')
          .toLowerCase()
          .includes(q),
      ),
    );
  }

  async bankAccount(id: string) {
    const item = await this.bankAccountsService.findOne(id);

    if (!item) {
      throw new NotFoundException('Bank account not found');
    }

    return item;
  }

  async updateBankAccount(id: string, body: FormBody) {
    return this.bankAccountsService.update(id, {
      bankName: this.required(body.bankName),
      accountTitle: this.nullable(body.accountTitle),
      accountHolder: this.nullable(body.accountHolder),
      accountNumber: this.nullable(body.accountNumber),
      cardNumber: this.nullable(body.cardNumber),
      shebaNumber: this.nullable(body.shebaNumber),
      notes: this.nullable(body.notes),
      archivedAt: body.archived === '1' ? new Date().toISOString() : null,
    });
  }

  async cheques(query = '') {
    const [cheques, companies, bankAccounts] = await Promise.all([
      this.chequesService.findAll(),
      this.companiesService.findAll(),
      this.bankAccountsService.findAll(),
    ]);

    const companyNames = new Map(companies.map((item) => [item.id, item.name]));

    const accountNames = new Map(
      bankAccounts.map((item) => [item.id, item.accountTitle || item.bankName]),
    );

    const rows = cheques.map((item) => ({
      ...item,
      companyName: companyNames.get(item.companyId) ?? item.companyId,
      bankAccountName:
        accountNames.get(item.bankAccountId) ?? item.bankAccountId,
    }));

    const q = query.trim().toLowerCase();

    if (!q) {
      return rows;
    }

    return rows.filter((item) =>
      [
        item.chequeNumber,
        item.companyName,
        item.bankAccountName,
        item.status,
        item.sayadStatus,
        item.sayadId,
        item.description,
        item.amount,
      ].some((value) =>
        String(value ?? '')
          .toLowerCase()
          .includes(q),
      ),
    );
  }

  async cheque(id: string) {
    const [item, companies, bankAccounts] = await Promise.all([
      this.chequesService.findOne(id),
      this.companiesService.findAll(),
      this.bankAccountsService.findAll(),
    ]);

    if (!item) {
      throw new NotFoundException('Cheque not found');
    }

    return {
      item,
      companies,
      bankAccounts,
    };
  }

  async updateCheque(id: string, body: FormBody) {
    const amount = Number(String(body.amount ?? '').replace(/[^0-9.-]/g, ''));

    if (!Number.isFinite(amount) || amount < 0) {
      throw new Error('Invalid cheque amount');
    }

    return this.chequesService.update(id, {
      chequeNumber: this.required(body.chequeNumber),
      amount,
      chequeDate: this.required(body.chequeDate),
      dueDate: this.nullable(body.dueDate),
      companyId: this.required(body.companyId),
      bankAccountId: this.required(body.bankAccountId),
      status: this.nullable(body.status),
      sayadStatus: this.nullable(body.sayadStatus),
      isRegisteredInSayad: body.isRegisteredInSayad === '1',
      sayadId: this.nullable(body.sayadId),
      description: this.nullable(body.description),
      archivedAt: body.archived === '1' ? new Date().toISOString() : null,
    });
  }

  private required(value: string | undefined): string {
    const text = String(value ?? '').trim();

    if (!text) {
      throw new Error('Required field is empty');
    }

    return text;
  }

  private optional(value: string | undefined): string | undefined {
    const text = String(value ?? '').trim();
    return text || undefined;
  }

  private nullable(value: string | undefined): string | null {
    const text = String(value ?? '').trim();
    return text || null;
  }
}
