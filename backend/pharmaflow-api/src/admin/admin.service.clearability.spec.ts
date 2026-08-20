import { AdminService } from './admin.service';
import { CompaniesService } from '../companies/companies.service';
import { BankAccountsService } from '../bank-accounts/bank-accounts.service';
import { ChequesService } from '../cheques/cheques.service';

describe('AdminService clearability', () => {
  let service: AdminService;

  const companiesService = {} as CompaniesService;

  const bankAccountsService = {
    update: jest.fn(),
  } as unknown as BankAccountsService;

  const chequesService = {
    update: jest.fn(),
  } as unknown as ChequesService;

  beforeEach(() => {
    jest.clearAllMocks();

    service = new AdminService(
      companiesService,
      bankAccountsService,
      chequesService,
    );
  });

  it('clears nullable BankAccount fields and unarchives', async () => {
    (bankAccountsService.update as jest.Mock).mockResolvedValue({
      id: 'bank-id',
    });

    await service.updateBankAccount('bank-id', {
      bankName: 'بانک تست',
      accountTitle: '',
      accountHolder: '   ',
      accountNumber: '',
      cardNumber: '',
      shebaNumber: '',
      notes: '',
      archived: '0',
    });

    expect(bankAccountsService.update).toHaveBeenCalledWith('bank-id', {
      bankName: 'بانک تست',
      accountTitle: null,
      accountHolder: null,
      accountNumber: null,
      cardNumber: null,
      shebaNumber: null,
      notes: null,
      archivedAt: null,
    });
  });

  it('clears nullable Cheque fields and unarchives', async () => {
    (chequesService.update as jest.Mock).mockResolvedValue({
      id: 'cheque-id',
    });

    await service.updateCheque('cheque-id', {
      chequeNumber: '12345',
      amount: '1000000',
      chequeDate: '2026-08-14',
      dueDate: '',
      companyId: '11111111-1111-4111-8111-111111111111',
      bankAccountId: '22222222-2222-4222-8222-222222222222',
      status: '',
      sayadStatus: '',
      sayadId: '',
      description: '',
      isRegisteredInSayad: '0',
      archived: '0',
    });

    expect(chequesService.update).toHaveBeenCalledWith('cheque-id', {
      chequeNumber: '12345',
      amount: 1000000,
      chequeDate: '2026-08-14',
      dueDate: null,
      companyId: '11111111-1111-4111-8111-111111111111',
      bankAccountId: '22222222-2222-4222-8222-222222222222',
      status: null,
      sayadStatus: null,
      isRegisteredInSayad: false,
      sayadId: null,
      description: null,
      archivedAt: null,
    });
  });

  it('still archives when archive is selected', async () => {
    (bankAccountsService.update as jest.Mock).mockResolvedValue({
      id: 'bank-id',
    });

    await service.updateBankAccount('bank-id', {
      bankName: 'بانک تست',
      archived: '1',
    });

    const call = (bankAccountsService.update as jest.Mock).mock.calls[0][1];

    expect(call.archivedAt).toEqual(expect.any(String));
    expect(Number.isNaN(Date.parse(call.archivedAt))).toBe(false);
  });
});
