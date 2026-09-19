import { PrismaService } from './database/prisma/prisma.service';
export declare class AppService {
    private readonly prisma;
    constructor(prisma: PrismaService);
    getHello(): Promise<{
        message: string;
        companies: {
            id: string;
            name: string;
            nationalId: string | null;
            economicCode: string | null;
            bankName: string | null;
            accountNumber: string | null;
            cardNumber: string | null;
            shebaNumber: string | null;
            notes: string | null;
            visitorName: string | null;
            visitorPhone: string | null;
            accountantName: string | null;
            accountantPhone: string | null;
            createdAt: Date;
            updatedAt: Date;
            archivedAt: Date | null;
            deletedAt: Date | null;
        }[];
    }>;
}
