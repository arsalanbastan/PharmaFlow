import { PushOutboxService } from './push-outbox.service';

describe('PushOutboxService', () => {
  const db = {
    pushOutbox: {
      create: jest.fn(),
    },
  };

  let service: PushOutboxService;

  beforeEach(() => {
    jest.clearAllMocks();
    service = new PushOutboxService();
    db.pushOutbox.create.mockResolvedValue({
      id: 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
    });
  });

  it('queues a minimal ORDER_CREATED event for MANAGER delivery', async () => {
    await service.enqueueOrderCreated(
      {
        id: '22222222-2222-4222-8222-222222222222',
        itemText: 'آتورواستاتین 20',
        requestedByName: 'امیر',
      },
      db as never,
    );

    expect(db.pushOutbox.create).toHaveBeenCalledWith({
      data: {
        eventType: 'ORDER_CREATED',
        aggregateType: 'ORDER_REQUEST',
        aggregateId: '22222222-2222-4222-8222-222222222222',
        targetRole: 'MANAGER',
        payload: {
          type: 'ORDER_CREATED',
          orderId: '22222222-2222-4222-8222-222222222222',
          itemText: 'آتورواستاتین 20',
          requestedByName: 'امیر',
        },
      },
    });
  });
});
