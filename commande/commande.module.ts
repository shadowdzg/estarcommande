import { Module } from '@nestjs/common';
import { CommandeController } from './commande.controller';
import { CommandeService } from './commande.service';

@Module({
  controllers: [CommandeController],
  providers: [CommandeService],
  exports: [CommandeService], // Add this export
})
export class CommandeModule {}
