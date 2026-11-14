import { Module } from '@nestjs/common';
import { AuthModule } from '../auth/auth.module';
import { PriceIncreasesController } from './price-increases.controller';
import { PriceImageService } from './price-image.service';
import { PriceIncreasesService } from './price-increases.service';
import { PriceIncreaseStorageService } from './price-increase-storage.service';
@Module({
  imports: [AuthModule],
  controllers: [PriceIncreasesController],
  providers: [PriceImageService, PriceIncreasesService, PriceIncreaseStorageService],
})
export class PriceIncreasesModule {}
