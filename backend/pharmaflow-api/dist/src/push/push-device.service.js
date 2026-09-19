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
Object.defineProperty(exports, "__esModule", { value: true });
exports.PushDeviceService = void 0;
const common_1 = require("@nestjs/common");
const prisma_service_1 = require("../database/prisma/prisma.service");
let PushDeviceService = class PushDeviceService {
    prisma;
    constructor(prisma) {
        this.prisma = prisma;
    }
    async register(user, dto) {
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
                        notificationAggregationVersion: dto.notificationAggregationVersion ?? 0,
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
                    notificationAggregationVersion: dto.notificationAggregationVersion ?? 0,
                },
            });
        });
        return this.toPublicDevice(device);
    }
    async getPreferences(user, dto) {
        this.assertManager(user);
        const device = await this.findRegisteredDevice(user, dto.installationId, dto.appPackage);
        return this.toPublicPreferences(device);
    }
    async updatePreferences(user, dto) {
        this.assertManager(user);
        const device = await this.findRegisteredDevice(user, dto.installationId, dto.appPackage);
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
    async acknowledgeNotification(user, dto) {
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
            throw new common_1.NotFoundException('Push notification delivery not found.');
        }
        const now = new Date();
        await this.prisma.$transaction(async (tx) => {
            await tx.pushDelivery.updateMany({
                where: {
                    id: delivery.id,
                    acknowledgedAt: null,
                },
                data: {
                    acknowledgedAt: now,
                },
            });
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
    async acknowledgeAllNotifications(user, dto) {
        this.assertManager(user);
        const device = await this.findRegisteredDevice(user, dto.installationId, dto.appPackage);
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
    async unregister(user, dto) {
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
    async findRegisteredDevice(user, installationId, appPackage) {
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
            throw new common_1.NotFoundException('Push device is not registered.');
        }
        return device;
    }
    toPublicPreferences(device) {
        return {
            notificationsEnabled: device.notificationsEnabled,
            orderNotificationMode: device.orderNotificationMode,
            chequeNotificationMode: device.chequeNotificationMode,
            cashPaymentNotificationMode: device.cashPaymentNotificationMode,
        };
    }
    assertManager(user) {
        if (user.role !== 'MANAGER') {
            throw new common_1.ForbiddenException('Push device registration is only available to MANAGER users.');
        }
    }
    toPublicDevice(device) {
        return {
            id: device.id,
            platform: device.platform,
            appPackage: device.appPackage,
            isEnabled: device.isEnabled,
            lastSeenAt: device.lastSeenAt,
        };
    }
};
exports.PushDeviceService = PushDeviceService;
exports.PushDeviceService = PushDeviceService = __decorate([
    (0, common_1.Injectable)(),
    __metadata("design:paramtypes", [prisma_service_1.PrismaService])
], PushDeviceService);
//# sourceMappingURL=push-device.service.js.map