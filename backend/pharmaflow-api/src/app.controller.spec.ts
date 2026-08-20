import { Test, TestingModule } from '@nestjs/testing';

import { PrismaService } from './database/prisma/prisma.service';
import { AppController } from './app.controller';
import { AppService } from './app.service';

describe('AppController', () => {
  let appController: AppController;

  const prisma = {
    company: {
      findMany: jest.fn(),
    },
  };

  beforeEach(async () => {
    jest.clearAllMocks();
    prisma.company.findMany.mockResolvedValue([]);

    const app: TestingModule = await Test.createTestingModule({
      controllers: [AppController],
      providers: [
        AppService,
        {
          provide: PrismaService,
          useValue: prisma,
        },
      ],
    }).compile();

    appController = app.get<AppController>(AppController);
  });

  describe('root', () => {
    it('returns backend status and companies from AppService', async () => {
      await expect(appController.getHello()).resolves.toEqual({
        message: 'PharmaFlow Backend is running',
        companies: [],
      });

      expect(prisma.company.findMany).toHaveBeenCalledTimes(1);
    });
  });
});
