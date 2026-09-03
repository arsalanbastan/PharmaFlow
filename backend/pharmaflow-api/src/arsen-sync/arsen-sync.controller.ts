import { Body, Controller, Get, Post, UseGuards } from '@nestjs/common';

import { ArsenSyncGuard } from './arsen-sync.guard';
import { ArsenSyncService } from './arsen-sync.service';
import { ArsenCatalogItemBatchDto } from './dto/arsen-catalog-item-batch.dto';
import { ArsenInvoiceBatchDto } from './dto/arsen-invoice-batch.dto';

@Controller('api/v1/integrations/arsen')
@UseGuards(ArsenSyncGuard)
export class ArsenSyncController {
  constructor(private readonly arsenSyncService: ArsenSyncService) {}

  @Get('status')
  status() {
    return this.arsenSyncService.status();
  }

  @Post('invoices/batch')
  ingest(@Body() body: ArsenInvoiceBatchDto) {
    return this.arsenSyncService.ingest(body.invoices);
  }

  @Post('items/batch')
  ingestItems(@Body() body: ArsenCatalogItemBatchDto) {
    return this.arsenSyncService.ingestCatalogItems(body.items);
  }
}
