import { INestApplication, ValidationPipe } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import request from 'supertest';
import { AuthGuard } from '../auth/auth.guard';
import { RolesGuard } from '../auth/roles.guard';
import { PermissionsGuard } from '../auth/permissions.guard';
import { PriceIncreasesController } from './price-increases.controller';
import { PriceImageService } from './price-image.service';
import { PriceIncreasesService } from './price-increases.service';

const id = 'b36c99fa-714b-4ab3-a36e-13632a32a398';
describe('Price increase HTTP access boundary', () => {
  let app: INestApplication;
  const service = {
    list: jest.fn().mockResolvedValue({ items: [], total: 0 }),
    create: jest.fn().mockResolvedValue({ id }),
    confirm: jest.fn().mockResolvedValue({ id }),
    prepare: jest.fn().mockResolvedValue({ id }),
    confirmAttachment: jest.fn(),
    download: jest.fn().mockResolvedValue({ downloadUrl: 'signed' }),
  };
  beforeAll(async () => {
    const module = await Test.createTestingModule({
      controllers: [PriceIncreasesController],
      providers: [
        PriceImageService,
        { provide: PriceIncreasesService, useValue: service },
        RolesGuard,
        PermissionsGuard,
      ],
    })
      .overrideGuard(AuthGuard)
      .useValue({
        canActivate: (ctx: any) => {
          const req = ctx.switchToHttp().getRequest();
          if (!req.headers['x-test-role']) return false;
          req.pharmaflowUser = {
            userId: id,
            displayName: 'Authenticated user',
            role: req.headers['x-test-role'],
            permissions: {
              managerAppAccess: req.headers['x-test-permit'] !== 'no',
              canCreateOrders: req.headers['x-test-permit'] !== 'no',
            },
          };
          return true;
        },
      })
      .compile();
    app = module.createNestApplication();
    app.useGlobalPipes(
      new ValidationPipe({
        whitelist: true,
        forbidNonWhitelisted: true,
        transform: true,
      }),
    );
    await app.init();
  });
  afterAll(async () => app.close());
  const body = {
    productName: 'دارو',
    category: 'DRUG',
    newPrice: '10000',
    effectiveDate: '1405/08/18',
    source: 'شرکت',
  };
  it('denies unauthenticated access', async () => {
    await request(app.getHttpServer())
      .get('/api/v1/price-increases')
      .expect(403);
  });
  it('allows staff to view history', async () => {
    await request(app.getHttpServer())
      .get('/api/v1/price-increases')
      .set('x-test-role', 'STAFF')
      .expect(200);
  });
  it('denies creation by staff', async () => {
    await request(app.getHttpServer())
      .post('/api/v1/price-increases')
      .set('x-test-role', 'STAFF')
      .send(body)
      .expect(403);
  });
  it('allows manager creation', async () => {
    await request(app.getHttpServer())
      .post('/api/v1/price-increases')
      .set('x-test-role', 'MANAGER')
      .send(body)
      .expect(201);
  });
  it('requires manager permission for creation', async () => {
    await request(app.getHttpServer())
      .post('/api/v1/price-increases')
      .set('x-test-role', 'MANAGER')
      .set('x-test-permit', 'no')
      .send(body)
      .expect(403);
  });
  it('rejects forged identity and timestamp fields', async () => {
    await request(app.getHttpServer())
      .post('/api/v1/price-increases')
      .set('x-test-role', 'MANAGER')
      .send({ ...body, createdByUserId: id, confirmedAt: '2020-01-01' })
      .expect(400);
  });
  it('allows staff confirmation', async () => {
    await request(app.getHttpServer())
      .post(`/api/v1/price-increases/${id}/confirm`)
      .set('x-test-role', 'STAFF')
      .expect(201);
  });
  it('requires staff order permission for confirmation', async () => {
    await request(app.getHttpServer())
      .post(`/api/v1/price-increases/${id}/confirm`)
      .set('x-test-role', 'STAFF')
      .set('x-test-permit', 'no')
      .expect(403);
  });
  it('denies manager impersonation of a staff confirmation', async () => {
    await request(app.getHttpServer())
      .post(`/api/v1/price-increases/${id}/confirm`)
      .set('x-test-role', 'MANAGER')
      .expect(403);
  });
  it('denies staff attachment mutations', async () => {
    await request(app.getHttpServer())
      .post(`/api/v1/price-increases/${id}/attachments/prepare`)
      .set('x-test-role', 'STAFF')
      .send({ fileName: 'a.pdf', mimeType: 'application/pdf', fileSize: 10 })
      .expect(403);
  });
  it('rejects malformed IDs', async () => {
    await request(app.getHttpServer())
      .post('/api/v1/price-increases/invalid/confirm')
      .set('x-test-role', 'STAFF')
      .expect(400);
  });
  it('rejects oversized and executable uploads', async () => {
    await request(app.getHttpServer())
      .post(`/api/v1/price-increases/${id}/attachments/prepare`)
      .set('x-test-role', 'MANAGER')
      .send({
        fileName: 'a.html',
        mimeType: 'text/html',
        fileSize: 20 * 1024 * 1024,
      })
      .expect(400);
  });
});
