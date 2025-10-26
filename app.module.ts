import { Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { AppController } from './app.controller';
import { AppService } from './app.service';
import { PrismaModule } from './prisma/prisma.module';
import { AuthModule } from './auth/auth.module';
import { CommandeModule } from './commande/commande.module';
import { UsersModule } from './users/users.module';
import { ClientsModule } from './clients/clients.module';
import { ZonesModule } from './zones/zones.module';
import { ProductsModule } from './produit/products.module';
import { FournisseursModule } from './fournisseur/fournisseurs.module';
import { WebSocketModule } from './websocket/websocket.module';

@Module({
  imports: [
    ConfigModule.forRoot(),
    PrismaModule,
    AuthModule,
    CommandeModule,
    UsersModule,
    ClientsModule,
    ZonesModule,
    ProductsModule,
    FournisseursModule,
    WebSocketModule,
  ],
  controllers: [AppController],
  providers: [AppService],
})
export class AppModule {}

