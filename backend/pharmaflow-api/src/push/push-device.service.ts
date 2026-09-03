import {
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';

import type { AuthPrincipal } from '../auth/auth.types';
import { PrismaService } from '../database/prisma/prisma.service';
import { AcknowledgePushNotificationDto } from './dto/acknowledge-push-notification.dto';
import { ReadPushDevicePreferencesDto } from './dto/read-push-device-preferences.dto';
import { RegisterPushDeviceDto } from './dto/register-push-device.dto';
import { UnregisterPushDeviceDto } from './dto/unregister-push-device.dto';
import { UpdatePushDevicePreferencesDto } from './dto/update-push-device-preferences.dto';

@Injectable()
export class PushDeviceService {
  constructor(private readonly prisma: PrismaService) {}

  async register(user: AuthPrincipal, dto: RegisterPushDeviceDto) {
    this.assertManager(user);

    const now = new Date();
    const token = dto.token.trim();
    const installationId = dto.installationId.trim();
    const appPackage = dto.appPackage.trim();

    const device = await this.prisma.$transaction(async (tx) => {
      const existing = await tx.pushDevice.findFirst({
        where: {
          userId: user.userId,
          installationId,
          appPackage,
        },
      });

      await tx.pushDevice.deleteMany({
        where: {
          fcmToken: token,
          ...(existing == null
            ? {}
            : {
                id: {
                  not: existing.id,
                },
              }),
        },
      });

      if (existing != null) {
        return tx.pushDevice.update({
          where: {
            id: existing.id,
          },
          data: {
            fcmToken: token,
            platform: dto.platform,
            isEnabled: true,
            revokedAt: null,
            lastSeenAt: now,
            notificationAggregationVersion:
              dto.notificationAggregationVersion ?? 0,
          },
        });
      }

      return tx.pushDevice.create({
        data: {
          userId: user.userId,
          fcmToken: token,
          installationId,
          platform: dto.platform,
          appPackage,
          isEnabled: true,
          lastSeenAt: now,
          notificationAggregationVersion:
            dto.notificationAggregationVersion ?? 0,
        },
      });
    });

    return this.toPublicDevice(device);
  }

  async getPreferences(user: AuthPrincipal, dto: ReadPushDevicePreferencesDto) {
    this.assertManager(user);

    const device = await this.findRegisteredDevice(
      user,
      dto.installationId,
      dto.appPackage,
    );

    return this.toPublicPreferences(device);
  }

  async updatePreferences(
    user: AuthPrincipal,
    dto: UpdatePushDevicePreferencesDto,
  ) {
    this.assertManager(user);

    const device = await this.findRegisteredDevice(
      user,
      dto.installationId,
      dto.appPackage,
    );

    const updated = await this.prisma.pushDevice.update({
      where: {
        id: device.id,
      },
      data: {
        notificationsEnabled: dto.notificationsEnabled,
        orderNotificationMode: dto.orderNotificationMode,
        chequeNotificationMode: dto.chequeNotificationMode,
        cashPaymentNotificationMode: dto.cashPaymentNotificationMode,
        lastSeenAt: new Date(),
      },
    });

    return this.toPublicPreferences(updated);
  }
  async acknowledgeNotification(
    user: AuthPrincipal,
    dto: AcknowledgePushNotificationDto,
  ) {
    this.assertManager(user);

    const delivery = await this.prisma.pushDelivery.findFirst({
      where: {
        id: dto.deliveryId,
        device: {
          is: {
            userId: user.userId,
          },
        },
      },
      select: {
        id: true,
        deviceId: true,
        deliverySequence: true,
        outbox: {
          select: {
            eventType: true,
          },
        },
      },
    });

    if (delivery == null || delivery.deviceId == null) {
      throw new NotFoundException('Push notification delivery not found.');
    }

    const now = new Date();

    await this.prisma.$transaction(async (tx) => {
      // The tapped delivery can reach the phone milliseconds before the
      // worker persists SENT, so acknowledge it independently of status.
      await tx.pushDelivery.updateMany({
        where: {
          id: delivery.id,
          acknowledgedAt: null,
        },
        data: {
          acknowledgedAt: now,
        },
      });

      // Reset only notifications that were already actually sent and are
      // not newer than the notification the user tapped.
      await tx.pushDelivery.updateMany({
        where: {
          deviceId: delivery.deviceId,
          status: 'SENT',
          acknowledgedAt: null,
          deliverySequence: {
            lte: delivery.deliverySequence,
          },
          outbox: {
            eventType: delivery.outbox.eventType,
          },
        },
        data: {
          acknowledgedAt: now,
        },
      });
    });

    return {
      ok: true,
    };
  }

  async acknowledgeAllNotifications(
    user: AuthPrincipal,
    dto: ReadPushDevicePreferencesDto,
  ) {
    this.assertManager(user);

    const device = await this.findRegisteredDevice(
      user,
      dto.installationId,
      dto.appPackage,
    );

    const result = await this.prisma.pushDelivery.updateMany({
      where: {
        deviceId: device.id,
        status: 'SENT',
        acknowledgedAt: null,
      },
      data: {
        acknowledgedAt: new Date(),
      },
    });

    return {
      ok: true,
      acknowledgedCount: result.count,
    };
  }

  async unregister(user: AuthPrincipal, dto: UnregisterPushDeviceDto) {
    this.assertManager(user);

    const now = new Date();

    await this.prisma.pushDevice.updateMany({
      where: {
        userId: user.userId,
        installationId: dto.installationId.trim(),
        appPackage: dto.appPackage.trim(),
        isEnabled: true,
      },
      data: {
        isEnabled: false,
        revokedAt: now,
        lastSeenAt: now,
      },
    });

    return {
      ok: true,
    };
  }

  private async findRegisteredDevice(
    user: AuthPrincipal,
    installationId: string,
    appPackage: string,
  ) {
    const device = await this.prisma.pushDevice.findFirst({
      where: {
        userId: user.userId,
        installationId: installationId.trim(),
        appPackage: appPackage.trim(),
        isEnabled: true,
        revokedAt: null,
      },
    });

    if (device == null) {
      throw new NotFoundException('Push device is not registered.');
    }

    return device;
  }

  private toPublicPreferences(device: {
    notificationsEnabled: boolean;
    orderNotificationMode: string;
    chequeNotificationMode: string;
    cashPaymentNotificationMode: string;
  }) {
    return {
      notificationsEnabled: device.notificationsEnabled,
      orderNotificationMode: device.orderNotificationMode,
      chequeNotificationMode: device.chequeNotificationMode,
      cashPaymentNotificationMode: device.cashPaymentNotificationMode,
    };
  }
  private assertManager(user: AuthPrincipal): void {
    if (user.role !== 'MANAGER') {
      throw new ForbiddenException(
        'Push device registration is only available to MANAGER users.',
      );
    }
  }

  private toPublicDevice(device: {
    id: string;
    platform: string;
    appPackage: string;
    isEnabled: boolean;
    lastSeenAt: Date;
  }) {
    return {
      id: device.id,
      platform: device.platform,
      appPackage: device.appPackage,
      isEnabled: device.isEnabled,
      lastSeenAt: device.lastSeenAt,
    };
  }
}
