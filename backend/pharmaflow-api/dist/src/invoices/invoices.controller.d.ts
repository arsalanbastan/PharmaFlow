import { UpdateInvoicePaymentStatusDto } from './dto/update-invoice-payment-status.dto';
import { CreateInvoiceSettlementDto } from './dto/create-invoice-settlement.dto';
import { InvoicesService } from './invoices.service';
export declare class InvoicesController {
    private readonly invoices;
    constructor(invoices: InvoicesService);
    findAll(q?: string, companyId?: string, dateFrom?: string, dateTo?: string, page?: string, pageSize?: string): Promise<{
        items: {
            company: {
                id: string;
                name: string;
            };
            paidAmount: string;
            discountAmount: string;
            settledAmount: string;
            remainingAmount: string;
            paymentStatus: string;
            isPaid: boolean;
            id: string;
            arsenFactorId: number;
            invoiceNumber: string | null;
            invoiceDate: string | null;
            settlementDate: string | null;
            factorDocType: number;
            factorDocTypeName: string | null;
            factorPayablePrice: string | null;
            paymentDays: number | null;
            itemCount: number;
            isDeletedInArsen: boolean;
        }[];
        page: number;
        pageSize: number;
        totalCount: number;
        totalPages: number;
    }>;
    prepareSettlement(invoiceIds?: string): Promise<{
        company: {
            id: string;
            name: string;
        };
        invoices: {
            paidAmount: string;
            discountAmount: string;
            settledAmount: string;
            remainingAmount: string;
            paymentStatus: string;
            isPaid: boolean;
            id: string;
            invoiceNumber: string | null;
            invoiceDate: string | null;
            factorPayablePrice: string | null;
        }[];
        totalRemainingAmount: string;
        bankAccounts: {
            id: string;
            bankName: string;
            accountNumber: string | null;
            accountTitle: string | null;
        }[];
    }>;
    createSettlement(dto: CreateInvoiceSettlementDto): Promise<{
        invoiceIds: string[];
        company: {
            id: string;
            name: string;
        };
        chequeId: string | null;
        cashPaymentId: string | null;
        chequeAmount: string;
        cashAmount: string;
        discountAmount: string;
        settledAmount: string;
        remainingAmount: string;
    }>;
    updatePaymentStatus(id: string, dto: UpdateInvoicePaymentStatusDto): Promise<void>;
    findOne(id: string): Promise<{
        company: {
            id: string;
            name: string;
        };
        items: {
            id: string;
            arsenFactorDetailId: string;
            arsenFactorDetailsId: number | null;
            arsenDrugId: string | null;
            drugName: string | null;
            barcode: string | null;
            packetQuantity: number | null;
            quantity: number | null;
            salePrice: string | null;
            purchasePrice: string | null;
            rowDiscount: string | null;
            hasTax: number | null;
            expireDate: string | null;
            batchNumber: string | null;
        }[];
        paidAmount: string;
        discountAmount: string;
        settledAmount: string;
        remainingAmount: string;
        paymentStatus: string;
        isPaid: boolean;
        id: string;
        arsenFactorId: number;
        invoiceNumber: string | null;
        invoiceDate: string | null;
        docDate: string | null;
        settlementDate: string | null;
        description: string | null;
        factorDocType: number;
        factorDocTypeName: string | null;
        factorType: number | null;
        factorTypeName: string | null;
        factorItemType: string | null;
        arsenBusinessPartnerId: number;
        arsenBusinessPartnerName: string;
        factorTotalPrice: string | null;
        factorDiscount: string | null;
        factorTax: string | null;
        factorPayablePrice: string | null;
        barbariPrice: string | null;
        paymentDays: number | null;
        itemCount: number;
        isDeletedInArsen: boolean;
        isLockedInArsen: boolean | null;
    }>;
}
