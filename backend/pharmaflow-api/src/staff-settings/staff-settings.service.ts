import { BadRequestException, Injectable } from '@nestjs/common';
import { signPosPayload, verifyPosReceipt } from './pos-crypto';
import { VerifyPosReceiptDto } from './dto/verify-pos-receipt.dto';
import { CreatePosGrantDto } from './dto/create-pos-grant.dto';
import type { Prisma } from '@prisma/client';

import { PrismaService } from '../database/prisma/prisma.service';
import { UpdateStaffPosSettingsDto } from './dto/update-staff-pos-settings.dto';

type PosDevice = {
  id: string;
  name: string;
  ip: string;
  terminalId: string;
  timeout: number;
  enabled: boolean;
};

@Injectable()
export class StaffSettingsService {
  constructor(private readonly prisma: PrismaService) {}

  async posSettings() {
    const row = await this.prisma.staffWebSettings.upsert({
      where: { id: 'default' },
      update: {},
      create: { id: 'default', posBridgePort: 17905, posDevices: [] },
    });

    return this.serialize(row);
  }

  async updatePosSettings(dto: UpdateStaffPosSettingsDto) {
    const devices = dto.devices.map((device) => ({
      id: device.id.trim(),
      name: device.name.trim(),
      ip: device.ip.trim(),
      terminalId: device.terminalId.trim(),
      timeout: device.timeout,
      enabled: device.enabled,
    }));

    const row = await this.prisma.staffWebSettings.upsert({
      where: { id: 'default' },
      update: {
        posBridgeHost: dto.bridgeHost?.trim() || null,
        posBridgePort: dto.bridgePort,
        posDevices: devices as Prisma.InputJsonValue,
      },
      create: {
        id: 'default',
        posBridgeHost: dto.bridgeHost?.trim() || null,
        posBridgePort: dto.bridgePort,
        posDevices: devices as Prisma.InputJsonValue,
      },
    });

    return this.serialize(row);
  }

  async issueGrant(dto: CreatePosGrantDto, actorId: string) {
    const config = await this.posSettings();
    const device = config.devices.find((value) => value.id === dto.deviceId && value.enabled);
    if (!device) throw new BadRequestException('POS device is not enabled or not configured.');
    if (dto.operation === 'purchase' && dto.amount < 1000) {
      throw new BadRequestException('POS payment amount must be at least 1000 rials.');
    }
    if (dto.operation !== 'purchase' && dto.amount !== 0) {
      throw new BadRequestException('Non-purchase grants must have zero amount.');
    }
    const expiresAt = Date.now() + 60_000;
    const grant = signPosPayload('v1', {
      bridge: 'PharmaFlowPOSBridge',
      operation: dto.operation,
      requestId: dto.requestId,
      deviceId: device.id,
      ip: device.ip,
      terminalId: device.terminalId,
      amount: dto.amount,
      expiresAt,
      actorId,
    });
    return { grant, expiresAt };
  }

  async verifyReceipt(dto: VerifyPosReceiptDto) {
    const receipt = verifyPosReceipt(dto.receipt);
    if (receipt.deviceId !== dto.deviceId || receipt.amount !== dto.amount) {
      throw new BadRequestException('POS receipt does not match the selected device or amount.');
    }
    const config = await this.posSettings();
    const device = config.devices.find((row) => row.id === dto.deviceId);
    if (!device || device.terminalId !== receipt.terminalId) {
      throw new BadRequestException('POS receipt terminal is not registered.');
    }
    return {
      ok: true,
      responseCode: receipt.responseCode,
      terminalId: receipt.terminalId,
      traceNumber: receipt.traceNumber ?? '',
      rrn: receipt.rrn ?? '',
      responseDescription: receipt.responseDescription ?? '',
      paidAt: receipt.paidAt,
    };
  }

  private serialize(row: {
    posBridgeHost: string | null;
    posBridgePort: number;
    posDevices: Prisma.JsonValue;
  }) {
    const rawDevices = Array.isArray(row.posDevices) ? row.posDevices : [];
    const devices = rawDevices
      .filter((value): value is Prisma.JsonObject => value != null && typeof value === 'object' && !Array.isArray(value))
      .map((value) => this.normalizeDevice(value))
      .filter((value): value is PosDevice => value != null);

    return {
      bridgeHost: row.posBridgeHost,
      bridgePort: row.posBridgePort,
      devices,
    };
  }

  private normalizeDevice(value: Prisma.JsonObject): PosDevice | null {
    const id = String(value.id ?? '').trim();
    const name = String(value.name ?? '').trim();
    const ip = String(value.ip ?? '').trim();
    const terminalId = String(value.terminalId ?? '').trim();
    const timeout = Number(value.timeout ?? 60);
    const enabled = value.enabled !== false;

    if (!id || !name || !ip || !terminalId || !Number.isFinite(timeout)) {
      return null;
    }

    return {
      id,
      name,
      ip,
      terminalId,
      timeout: Math.max(10, Math.min(180, Math.trunc(timeout))),
      enabled,
    };
  }
}
