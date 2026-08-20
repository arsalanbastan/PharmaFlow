import { GUARDS_METADATA } from '@nestjs/common/constants';

import { CashPaymentAttachmentsController } from '../cash-payments/cash-payment-attachments.controller';
import { CashPaymentsController } from '../cash-payments/cash-payments.controller';
import { ChequeAttachmentsController } from '../cheques/cheque-attachments.controller';
import { ChequesController } from '../cheques/cheques.controller';
import { AuthGuard } from './auth.guard';
import {
  AUTH_PERMISSIONS_KEY,
  type AppUserPermissionKey,
} from './permissions.decorator';
import { PermissionsGuard } from './permissions.guard';
import { AUTH_ROLES_KEY } from './roles.decorator';
import { RolesGuard } from './roles.guard';

type ControllerMethod = (...args: never[]) => unknown;

function expectCreatePermission(
  method: ControllerMethod,
  permission: AppUserPermissionKey,
): void {
  const guards =
    (Reflect.getMetadata(GUARDS_METADATA, method) as unknown[] | undefined) ??
    [];

  expect(guards).toEqual(expect.arrayContaining([AuthGuard, PermissionsGuard]));

  expect(Reflect.getMetadata(AUTH_PERMISSIONS_KEY, method)).toEqual([
    permission,
  ]);

  expect(Reflect.getMetadata(AUTH_ROLES_KEY, method)).toBeUndefined();
}

function expectManagerOnly(method: ControllerMethod): void {
  const guards =
    (Reflect.getMetadata(GUARDS_METADATA, method) as unknown[] | undefined) ??
    [];

  expect(guards).toEqual(expect.arrayContaining([AuthGuard, RolesGuard]));

  expect(Reflect.getMetadata(AUTH_ROLES_KEY, method)).toEqual(['MANAGER']);

  expect(Reflect.getMetadata(AUTH_PERMISSIONS_KEY, method)).toBeUndefined();
}

function expectPublicRead(method: ControllerMethod): void {
  expect(Reflect.getMetadata(AUTH_PERMISSIONS_KEY, method)).toBeUndefined();

  expect(Reflect.getMetadata(AUTH_ROLES_KEY, method)).toBeUndefined();

  expect(Reflect.getMetadata(GUARDS_METADATA, method)).toBeUndefined();
}

describe('financial permission enforcement', () => {
  it('allows permitted staff to create cheques', () => {
    expectCreatePermission(
      ChequesController.prototype.create,
      'canCreateCheques',
    );
  });

  it('restricts cheque update and delete to managers', () => {
    expectManagerOnly(ChequesController.prototype.update);
    expectManagerOnly(ChequesController.prototype.remove);
  });

  it('keeps cheque reads available', () => {
    expectPublicRead(ChequesController.prototype.findAll);
    expectPublicRead(ChequesController.prototype.findChanges);
    expectPublicRead(ChequesController.prototype.findOne);
  });

  it('allows permitted staff to upload new cheque statements', () => {
    expectCreatePermission(
      ChequeAttachmentsController.prototype.prepareUpload,
      'canCreateCheques',
    );

    expectCreatePermission(
      ChequeAttachmentsController.prototype.confirmUpload,
      'canCreateCheques',
    );
  });

  it('restricts cheque-statement deletion to managers', () => {
    expectManagerOnly(ChequeAttachmentsController.prototype.remove);
  });

  it('keeps cheque-statement reads and downloads available', () => {
    expectPublicRead(ChequeAttachmentsController.prototype.findAll);
    expectPublicRead(ChequeAttachmentsController.prototype.findChanges);
    expectPublicRead(ChequeAttachmentsController.prototype.createDownloadUrl);
  });

  it('allows permitted staff to create cash payments', () => {
    expectCreatePermission(
      CashPaymentsController.prototype.create,
      'canCreateCashPayments',
    );
  });

  it('restricts cash update and delete to managers', () => {
    expectManagerOnly(CashPaymentsController.prototype.update);
    expectManagerOnly(CashPaymentsController.prototype.remove);
  });

  it('keeps cash-payment reads available', () => {
    expectPublicRead(CashPaymentsController.prototype.findAll);
    expectPublicRead(CashPaymentsController.prototype.findChanges);
    expectPublicRead(CashPaymentsController.prototype.findOne);
  });

  it('allows permitted staff to upload new cash attachments', () => {
    expectCreatePermission(
      CashPaymentAttachmentsController.prototype.prepareUpload,
      'canCreateCashPayments',
    );

    expectCreatePermission(
      CashPaymentAttachmentsController.prototype.confirmUpload,
      'canCreateCashPayments',
    );
  });

  it('restricts attachment deletion to managers', () => {
    expectManagerOnly(CashPaymentAttachmentsController.prototype.remove);
  });

  it('keeps attachment reads and downloads available', () => {
    expectPublicRead(CashPaymentAttachmentsController.prototype.findAll);

    expectPublicRead(CashPaymentAttachmentsController.prototype.findChanges);

    expectPublicRead(
      CashPaymentAttachmentsController.prototype.createDownloadUrl,
    );
  });
});
