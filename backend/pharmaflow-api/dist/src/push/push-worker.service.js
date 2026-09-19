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
var PushWorkerService_1;
Object.defineProperty(exports, "__esModule", { value: true });
exports.PushWorkerService = void 0;
exports.pushTargetKey = pushTargetKey;
exports.notificationModeForEvent = notificationModeForEvent;
exports.pushRetryDelayMs = pushRetryDelayMs;
const common_1 = require("@nestjs/common");
const node_crypto_1 = require("node:crypto");
const prisma_service_1 = require("../database/prisma/prisma.service");
const firebase_push_sender_service_1 = require("./firebase-push-sender.service");
const WORKER_INTERVAL_MS = 15_000;
const WORKER_BATCH_SIZE = 10;
const NO_DEVICE_RETRY_MS = 60_000;
function pushTargetKey(input) {
    return (0, node_crypto_1.createHash)('sha256')
        .update(input.userId)
        .update('\0')
        .update(input.installationId)
        .update('\0')
        .update(input.appPackage)
        .digest('hex');
}
function notificationModeForEvent(device, eventType) {
    if (!device.notificationsEnabled) {
        return 'OFF';
    }
    const rawMode = eventType === 'ORDER_CREATED'
        ? device.orderNotificationMode
        : eventType === 'CHEQUE_CREATED'
            ? device.chequeNotificationMode
            : eventType === 'CASH_PAYMENT_CREATED'
                ? device.cashPaymentNotificationMode
                : 'OFF';
    return rawMode === 'AUDIBLE' || rawMode === 'SILENT' ? rawMode : 'OFF';
}
function pushRetryDelayMs(attempt) {
    const normalizedAttempt = Math.max(1, Math.min(attempt, 10));
    return Math.min(30_000 * 2 ** (normalizedAttempt - 1), 10 * 60_000);
}
let PushWorkerService = PushWorkerService_1 = class PushWorkerService {
    prisma;
    sender;
    logger = new common_1.Logger(PushWorkerService_1.name);
    timer = null;
    running = false;
    active = false;
    config = null;
    constructor(prisma, sender) {
        this.prisma = prisma;
        this.sender = sender;
    }
    async onModuleInit() {
        this.config = this.readConfig();
        if (!this.config.enabled) {
            return;
        }
        if (this.config.cutoverAt == null) {
            this.logger.warn('Push sender is enabled but PUSH_SENDER_CUTOVER_AT is missing or invalid; worker stays disabled.');
            return;
        }
        if (!this.sender.isConfigured()) {
            this.logger.warn('Push sender is enabled but Firebase credentials are not configured; worker stays disabled.');
            return;
        }
        this.active = true;
        try {
            await this.expireOldOutboxRows(this.config);
        }
        catch (error) {
            this.logger.warn(`Push backlog expiry failed during startup: ${this.errorName(error)}.`);
        }
        void this.runOnce();
        this.timer = setInterval(() => {
            void this.runOnce();
        }, WORKER_INTERVAL_MS);
    }
    onModuleDestroy() {
        if (this.timer != null) {
            clearInterval(this.timer);
            this.timer = null;
        }
        this.active = false;
    }
    async runOnce() {
        if (!this.active || this.running || this.config == null) {
            return;
        }
        this.running = true;
        try {
            await this.expireOldOutboxRows(this.config);
            for (let index = 0; index < WORKER_BATCH_SIZE; index++) {
                const outbox = await this.claimNextOutbox(this.config);
                if (outbox == null) {
                    break;
                }
                try {
                    await this.processOutbox(outbox, this.config);
                }
                catch (error) {
                    await this.releaseOutboxAfterFailure(outbox.id, error);
                }
            }
        }
        catch (error) {
            this.logger.warn(`Push worker cycle failed: ${this.errorName(error)}.`);
        }
        finally {
            this.running = false;
        }
    }
    async expireOldOutboxRows(config) {
        if (config.cutoverAt == null) {
            return;
        }
        await this.prisma.pushOutbox.updateMany({
            where: {
                status: {
                    in: ['PENDING', 'PROCESSING'],
                },
                createdAt: {
                    lt: config.cutoverAt,
                },
            },
            data: {
                status: 'EXPIRED',
                claimedAt: null,
                lastError: 'before-sender-cutover',
            },
        });
        const expiresBefore = new Date(Date.now() - config.ttlMs);
        await this.prisma.pushOutbox.updateMany({
            where: {
                status: {
                    in: ['PENDING', 'PROCESSING'],
                },
                createdAt: {
                    lt: expiresBefore,
                },
            },
            data: {
                status: 'EXPIRED',
                claimedAt: null,
                lastError: 'notification-ttl-expired',
            },
        });
    }
    async claimNextOutbox(config) {
        if (config.cutoverAt == null) {
            return null;
        }
        const now = new Date();
        const staleBefore = new Date(now.getTime() - config.claimStaleMs);
        const expiresBefore = new Date(now.getTime() - config.ttlMs);
        const rows = await this.prisma.$queryRaw `
      WITH candidate AS (
        SELECT "id"
        FROM "push_outbox"
        WHERE (
          "status" = 'PENDING'
          OR (
            "status" = 'PROCESSING'
            AND "claimedAt" IS NOT NULL
            AND "claimedAt" < ${staleBefore}
          )
        )
          AND "nextAttemptAt" <= ${now}
          AND "createdAt" >= ${config.cutoverAt}
          AND "createdAt" >= ${expiresBefore}
        ORDER BY "createdAt" ASC, "id" ASC
        FOR UPDATE SKIP LOCKED
        LIMIT 1
      )
      UPDATE "push_outbox" AS p
      SET
        "status" = 'PROCESSING',
        "claimedAt" = ${now},
        "attempts" = p."attempts" + 1,
        "updatedAt" = ${now}
      FROM candidate
      WHERE p."id" = candidate."id"
      RETURNING
        p."id",
        p."eventType",
        p."aggregateType",
        p."aggregateId",
        p."targetRole",
        p."attempts",
        p."createdAt"
    `;
        return rows[0] ?? null;
    }
    async processOutbox(outbox, config) {
        const supportedEvent = (outbox.eventType === 'ORDER_CREATED' &&
            outbox.aggregateType === 'ORDER_REQUEST') ||
            (outbox.eventType === 'CHEQUE_CREATED' &&
                outbox.aggregateType === 'CHEQUE') ||
            (outbox.eventType === 'CASH_PAYMENT_CREATED' &&
                outbox.aggregateType === 'CASH_PAYMENT');
        if (!supportedEvent || outbox.targetRole !== 'MANAGER') {
            await this.prisma.pushOutbox.update({
                where: {
                    id: outbox.id,
                },
                data: {
                    status: 'DROPPED',
                    claimedAt: null,
                    lastError: 'unsupported-push-event',
                },
            });
            return;
        }
        const devices = await this.prisma.pushDevice.findMany({
            where: {
                isEnabled: true,
                revokedAt: null,
                appPackage: {
                    in: ['com.example.pharmaflow', 'com.example.pharmaflow.dev'],
                },
                user: {
                    role: 'MANAGER',
                    isActive: true,
                },
            },
            select: {
                id: true,
                userId: true,
                fcmToken: true,
                installationId: true,
                appPackage: true,
                lastSeenAt: true,
                notificationsEnabled: true,
                orderNotificationMode: true,
                chequeNotificationMode: true,
                cashPaymentNotificationMode: true,
                notificationAggregationVersion: true,
            },
        });
        for (const device of devices) {
            const targetKey = pushTargetKey(device);
            let delivery = await this.prisma.pushDelivery.upsert({
                where: {
                    outboxId_targetKey: {
                        outboxId: outbox.id,
                        targetKey,
                    },
                },
                create: {
                    outboxId: outbox.id,
                    deviceId: device.id,
                    targetKey,
                },
                update: {
                    deviceId: device.id,
                },
            });
            const notificationMode = notificationModeForEvent(device, outbox.eventType);
            if (notificationMode === 'OFF') {
                if (delivery.status !== 'SENT') {
                    delivery = await this.prisma.pushDelivery.update({
                        where: {
                            id: delivery.id,
                        },
                        data: {
                            status: 'DEAD',
                            lastError: 'disabled-by-notification-preference',
                        },
                    });
                }
                continue;
            }
            if (delivery.status === 'DEAD' &&
                device.lastSeenAt.getTime() > delivery.updatedAt.getTime()) {
                delivery = await this.prisma.pushDelivery.update({
                    where: {
                        id: delivery.id,
                    },
                    data: {
                        status: 'PENDING',
                        attempts: 0,
                        nextAttemptAt: new Date(),
                        sentAt: null,
                        lastError: null,
                    },
                });
            }
            if (delivery.status === 'SENT' || delivery.status === 'DEAD') {
                continue;
            }
            if (delivery.nextAttemptAt.getTime() > Date.now()) {
                continue;
            }
            let notificationAggregation;
            if (device.notificationAggregationVersion >= 1) {
                const previousSentUnacknowledged = await this.prisma.pushDelivery.count({
                    where: {
                        deviceId: device.id,
                        status: 'SENT',
                        acknowledgedAt: null,
                        outbox: {
                            eventType: outbox.eventType,
                        },
                    },
                });
                notificationAggregation = {
                    deliveryId: delivery.id,
                    count: previousSentUnacknowledged + 1,
                };
            }
            const result = await this.sender.sendCreatedEvent(outbox.eventType, device.fcmToken, outbox.aggregateId, notificationMode, notificationAggregation);
            await this.applyDeliveryResult(delivery.id, device.id, device.fcmToken, delivery.attempts, result, config);
        }
        await this.settleOutbox(outbox.id);
    }
    async applyDeliveryResult(deliveryId, deviceId, token, previousAttempts, result, config) {
        const attempts = previousAttempts + 1;
        const now = new Date();
        if (result.kind === 'sent') {
            await this.prisma.pushDelivery.update({
                where: {
                    id: deliveryId,
                },
                data: {
                    status: 'SENT',
                    attempts,
                    sentAt: now,
                    lastError: null,
                },
            });
            return;
        }
        if (result.kind === 'invalid-token') {
            await this.prisma.$transaction([
                this.prisma.pushDevice.updateMany({
                    where: {
                        id: deviceId,
                        fcmToken: token,
                        isEnabled: true,
                    },
                    data: {
                        isEnabled: false,
                        revokedAt: now,
                    },
                }),
                this.prisma.pushDelivery.update({
                    where: {
                        id: deliveryId,
                    },
                    data: {
                        status: 'DEAD',
                        attempts,
                        lastError: result.code,
                    },
                }),
            ]);
            return;
        }
        if (attempts >= config.maxDeliveryAttempts) {
            await this.prisma.pushDelivery.update({
                where: {
                    id: deliveryId,
                },
                data: {
                    status: 'DEAD',
                    attempts,
                    lastError: result.code,
                },
            });
            return;
        }
        await this.prisma.pushDelivery.update({
            where: {
                id: deliveryId,
            },
            data: {
                status: 'PENDING',
                attempts,
                nextAttemptAt: new Date(now.getTime() + pushRetryDelayMs(attempts)),
                lastError: result.code,
            },
        });
    }
    async settleOutbox(outboxId) {
        const deliveries = await this.prisma.pushDelivery.findMany({
            where: {
                outboxId,
            },
            select: {
                status: true,
                nextAttemptAt: true,
            },
        });
        const pending = deliveries.filter((delivery) => delivery.status === 'PENDING');
        const hasSent = deliveries.some((delivery) => delivery.status === 'SENT');
        if (pending.length > 0) {
            const nextAttemptAt = pending.reduce((earliest, delivery) => delivery.nextAttemptAt < earliest ? delivery.nextAttemptAt : earliest, pending[0].nextAttemptAt);
            await this.prisma.pushOutbox.update({
                where: {
                    id: outboxId,
                },
                data: {
                    status: 'PENDING',
                    claimedAt: null,
                    nextAttemptAt,
                    lastError: null,
                },
            });
            return;
        }
        if (hasSent) {
            await this.prisma.pushOutbox.update({
                where: {
                    id: outboxId,
                },
                data: {
                    status: 'SENT',
                    claimedAt: null,
                    sentAt: new Date(),
                    lastError: null,
                },
            });
            return;
        }
        if (deliveries.length > 0) {
            await this.prisma.pushOutbox.update({
                where: {
                    id: outboxId,
                },
                data: {
                    status: 'DROPPED',
                    claimedAt: null,
                    lastError: 'no-deliverable-manager-device',
                },
            });
            return;
        }
        await this.prisma.pushOutbox.update({
            where: {
                id: outboxId,
            },
            data: {
                status: 'PENDING',
                claimedAt: null,
                nextAttemptAt: new Date(Date.now() + NO_DEVICE_RETRY_MS),
                lastError: 'no-deliverable-manager-device',
            },
        });
    }
    async releaseOutboxAfterFailure(outboxId, error) {
        try {
            await this.prisma.pushOutbox.updateMany({
                where: {
                    id: outboxId,
                    status: 'PROCESSING',
                },
                data: {
                    status: 'PENDING',
                    claimedAt: null,
                    nextAttemptAt: new Date(Date.now() + NO_DEVICE_RETRY_MS),
                    lastError: `worker-${this.errorName(error)}`,
                },
            });
        }
        catch (releaseError) {
            this.logger.warn(`Push outbox release failed: ${this.errorName(releaseError)}.`);
        }
    }
    readConfig() {
        return {
            enabled: process.env.PUSH_SENDER_ENABLED?.trim().toLowerCase() === 'true',
            cutoverAt: this.readIsoDate(process.env.PUSH_SENDER_CUTOVER_AT),
            ttlMs: this.readBoundedInteger(process.env.PUSH_EVENT_TTL_MINUTES, 60, 5, 24 * 60) *
                60 *
                1000,
            claimStaleMs: this.readBoundedInteger(process.env.PUSH_CLAIM_STALE_MINUTES, 5, 1, 60) *
                60 *
                1000,
            maxDeliveryAttempts: this.readBoundedInteger(process.env.PUSH_MAX_DELIVERY_ATTEMPTS, 5, 1, 10),
        };
    }
    readIsoDate(value) {
        const normalized = value?.trim() ?? '';
        if (!normalized) {
            return null;
        }
        const timestamp = Date.parse(normalized);
        if (!Number.isFinite(timestamp)) {
            return null;
        }
        return new Date(timestamp);
    }
    readBoundedInteger(value, fallback, minimum, maximum) {
        const parsed = Number.parseInt(value ?? '', 10);
        if (!Number.isFinite(parsed)) {
            return fallback;
        }
        return Math.max(minimum, Math.min(parsed, maximum));
    }
    errorName(error) {
        return error instanceof Error ? error.name : 'UnknownError';
    }
};
exports.PushWorkerService = PushWorkerService;
exports.PushWorkerService = PushWorkerService = PushWorkerService_1 = __decorate([
    (0, common_1.Injectable)(),
    __metadata("design:paramtypes", [prisma_service_1.PrismaService,
        firebase_push_sender_service_1.FirebasePushSenderService])
], PushWorkerService);
//# sourceMappingURL=push-worker.service.js.map