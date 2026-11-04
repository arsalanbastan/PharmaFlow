import { createHmac, timingSafeEqual } from 'node:crypto';
import { BadRequestException, ServiceUnavailableException } from '@nestjs/common';

function secret(): Buffer {
  const value = process.env.PHARMAFLOW_POS_BRIDGE_SIGNING_KEY?.trim() ?? '';
  if (!/^[0-9a-fA-F]{64}$/.test(value)) {
    throw new ServiceUnavailableException('POS signing key is not configured.');
  }
  return Buffer.from(value, 'hex');
}

function signature(base: string): string {
  return createHmac('sha256', secret()).update(base, 'utf8').digest('hex');
}

export function signPosPayload(prefix: 'v1' | 'r1', value: object): string {
  const body = Buffer.from(JSON.stringify(value), 'utf8').toString('base64url');
  const base = `${prefix}.${body}`;
  return `${base}.${signature(base)}`;
}

export type VerifiedPosReceipt = {
  requestId: string;
  deviceId: string;
  terminalId: string;
  amount: number;
  responseCode: string;
  responseDescription?: string;
  traceNumber?: string;
  rrn?: string;
  paidAt: string;
  ok: boolean;
};

export function verifyPosReceipt(receipt: string): VerifiedPosReceipt {
  if (receipt.length > 4096) throw new BadRequestException('Invalid POS receipt.');
  const parts = receipt.split('.');
  if (parts.length !== 3 || parts[0] !== 'r1' || !/^[0-9a-f]{64}$/i.test(parts[2])) {
    throw new BadRequestException('Invalid POS receipt format.');
  }
  const expected = Buffer.from(signature(`${parts[0]}.${parts[1]}`), 'hex');
  const supplied = Buffer.from(parts[2], 'hex');
  if (supplied.length !== expected.length || !timingSafeEqual(supplied, expected)) {
    throw new BadRequestException('POS receipt signature is invalid.');
  }
  let value: Record<string, unknown>;
  try {
    value = JSON.parse(Buffer.from(parts[1], 'base64url').toString('utf8')) as Record<string, unknown>;
  } catch {
    throw new BadRequestException('Invalid POS receipt payload.');
  }
  if (value?.ok !== true || value.responseCode !== '00' ||
      typeof value.requestId !== 'string' || !/^[A-Za-z0-9_-]{1,128}$/.test(value.requestId) ||
      typeof value.deviceId !== 'string' || typeof value.terminalId !== 'string' ||
      typeof value.amount !== 'number' || !Number.isSafeInteger(value.amount) ||
      typeof value.paidAt !== 'string') {
    throw new BadRequestException('POS receipt is not a verified successful payment.');
  }
  const timestamp = Date.parse(value.paidAt);
  if (!Number.isFinite(timestamp) || timestamp > Date.now() + 5 * 60_000 ||
      timestamp < Date.now() - 7 * 24 * 60 * 60_000) {
    throw new BadRequestException('POS receipt timestamp is out of range.');
  }
  return value as VerifiedPosReceipt;
}
