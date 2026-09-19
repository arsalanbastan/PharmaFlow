import { Prisma } from '@prisma/client';
type PushOutboxDatabase = Pick<Prisma.TransactionClient, 'pushOutbox'>;
type OrderCreatedForPush = {
    id: string;
    itemText: string;
    requestedByName: string;
};
export declare function enqueueChequeCreatedPush(chequeId: string, db: PushOutboxDatabase): Promise<void>;
export declare function enqueueCashPaymentCreatedPush(cashPaymentId: string, db: PushOutboxDatabase): Promise<void>;
export declare class PushOutboxService {
    enqueueOrderCreated(order: OrderCreatedForPush, db: PushOutboxDatabase): Promise<void>;
}
export {};
