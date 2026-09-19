import type { Response } from 'express';
import { PrismaService } from '../database/prisma/prisma.service';
export declare class HealthController {
    private readonly prisma;
    constructor(prisma: PrismaService);
    check(response: Response): Promise<{
        status: string;
        service: string;
        version: string;
        environment: string;
        database: {
            status: string;
        };
        serverTime: string;
        timestamp: string;
    }>;
}
