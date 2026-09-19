import { AppService } from './app.service';
export declare class AppController {
    private readonly appService;
    constructor(appService: AppService);
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
