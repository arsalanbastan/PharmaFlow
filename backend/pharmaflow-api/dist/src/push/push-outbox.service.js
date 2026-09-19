"use strict";
var __decorate = (this && this.__decorate) || function (decorators, target, key, desc) {
    var c = arguments.length, r = c < 3 ? target : desc === null ? desc = Object.getOwnPropertyDescriptor(target, key) : desc, d;
    if (typeof Reflect === "object" && typeof Reflect.decorate === "function") r = Reflect.decorate(decorators, target, key, desc);
    else for (var i = decorators.length - 1; i >= 0; i--) if (d = decorators[i]) r = (c < 3 ? d(r) : c > 3 ? d(target, key, r) : d(target, key)) || r;
    return c > 3 && r && Object.defineProperty(target, key, r), r;
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.PushOutboxService = void 0;
exports.enqueueChequeCreatedPush = enqueueChequeCreatedPush;
exports.enqueueCashPaymentCreatedPush = enqueueCashPaymentCreatedPush;
const common_1 = require("@nestjs/common");
async function enqueueCreatedEntity(input, db) {
    await db.pushOutbox.create({
        data: {
            eventType: input.eventType,
            aggregateType: input.aggregateType,
            aggregateId: input.aggregateId,
            targetRole: 'MANAGER',
            payload: {
                type: input.eventType,
                [input.idKey]: input.aggregateId,
            },
        },
    });
}
async function enqueueChequeCreatedPush(chequeId, db) {
    await enqueueCreatedEntity({
        eventType: 'CHEQUE_CREATED',
        aggregateType: 'CHEQUE',
        aggregateId: chequeId,
        idKey: 'chequeId',
    }, db);
}
async function enqueueCashPaymentCreatedPush(cashPaymentId, db) {
    await enqueueCreatedEntity({
        eventType: 'CASH_PAYMENT_CREATED',
        aggregateType: 'CASH_PAYMENT',
        aggregateId: cashPaymentId,
        idKey: 'cashPaymentId',
    }, db);
}
let PushOutboxService = class PushOutboxService {
    async enqueueOrderCreated(order, db) {
        await db.pushOutbox.create({
            data: {
                eventType: 'ORDER_CREATED',
                aggregateType: 'ORDER_REQUEST',
                aggregateId: order.id,
                targetRole: 'MANAGER',
                payload: {
                    type: 'ORDER_CREATED',
                    orderId: order.id,
                    itemText: order.itemText,
                    requestedByName: order.requestedByName,
                },
            },
        });
    }
};
exports.PushOutboxService = PushOutboxService;
exports.PushOutboxService = PushOutboxService = __decorate([
    (0, common_1.Injectable)()
], PushOutboxService);
//# sourceMappingURL=push-outbox.service.js.map