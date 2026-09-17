import { Injectable } from '@nestjs/common';
import { Prisma } from '@prisma/client';

type PushOutboxDatabase = Pick<Prisma.TransactionClient, 'pushOutbox'>;

type OrderCreatedForPush = {
  id: string;
  itemText: string;
  requestedByName: string;
};

type CreatedPushEventType = 'CHEQUE_CREATED' | 'CASH_PAYMENT_CREATED';

async function enqueueCreatedEntity(
  input: {
    eventType: CreatedPushEventType;
    aggregateType: 'CHEQUE' | 'CASH_PAYMENT';
    aggregateId: string;
    idKey: 'chequeId' | 'cashPaymentId';
  },
  db: PushOutboxDatabase,
): Promise<void> {
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

export async function enqueueChequeCreatedPush(
  chequeId: string,
  db: PushOutboxDatabase,
): Promise<void> {
  await enqueueCreatedEntity(
    {
      eventType: 'CHEQUE_CREATED',
      aggregateType: 'CHEQUE',
      aggregateId: chequeId,
      idKey: 'chequeId',
    },
    db,
  );
}

export async function enqueueCashPaymentCreatedPush(
  cashPaymentId: string,
  db: PushOutboxDatabase,
): Promise<void> {
  await enqueueCreatedEntity(
    {
      eventType: 'CASH_PAYMENT_CREATED',
      aggregateType: 'CASH_PAYMENT',
      aggregateId: cashPaymentId,
      idKey: 'cashPaymentId',
    },
    db,
  );
}

@Injectable()
export class PushOutboxService {
  async enqueueOrderCreated(
    order: OrderCreatedForPush,
    db: PushOutboxDatabase,
  ): Promise<void> {
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
}
