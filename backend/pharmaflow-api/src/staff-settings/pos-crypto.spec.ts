import { BadRequestException, ServiceUnavailableException } from '@nestjs/common';
import { signPosPayload, verifyPosReceipt } from './pos-crypto';

describe('POS signed receipts', () => {
  const previousKey = process.env.PHARMAFLOW_POS_BRIDGE_SIGNING_KEY;
  beforeEach(() => { process.env.PHARMAFLOW_POS_BRIDGE_SIGNING_KEY = 'ab'.repeat(32); });
  afterAll(() => {
    if (previousKey == null) delete process.env.PHARMAFLOW_POS_BRIDGE_SIGNING_KEY;
    else process.env.PHARMAFLOW_POS_BRIDGE_SIGNING_KEY = previousKey;
  });

  const valid = () => ({
    requestId: 'pf-12345-pos-1', deviceId: 'pos-1', terminalId: '200100',
    amount: 134500, responseCode: '00', ok: true,
    traceNumber: '12345', rrn: '654321', paidAt: new Date().toISOString(),
  });

  it('accepts a signed success', () => {
    expect(verifyPosReceipt(signPosPayload('r1', valid())).amount).toBe(134500);
  });
  it('rejects a tampered receipt', () => {
    const receipt = signPosPayload('r1', valid());
    const replacement = receipt.endsWith('0') ? '1' : '0';
    expect(() => verifyPosReceipt(receipt.substring(0, receipt.length - 1) + replacement)).toThrow(BadRequestException);
  });
  it('rejects a signed decline', () => {
    expect(() => verifyPosReceipt(signPosPayload('r1', { ...valid(), ok: false }))).toThrow(BadRequestException);
  });
  it('fails closed without key', () => {
    delete process.env.PHARMAFLOW_POS_BRIDGE_SIGNING_KEY;
    expect(() => signPosPayload('v1', valid())).toThrow(ServiceUnavailableException);
  });
});
