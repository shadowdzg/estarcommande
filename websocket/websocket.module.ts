import { Module } from '@nestjs/common';
import { WebSocketGateway } from './websocket.gateway';
import { CommandeModule } from '../commande/commande.module';
import { JwtModule } from '@nestjs/jwt';

@Module({
  imports: [
    CommandeModule,
    JwtModule.register({
      secret: process.env.JWT_SECRET || 'default-secret',
      signOptions: { expiresIn: process.env.JWT_EXPIRY || '1d' },
    }),
  ],
  providers: [WebSocketGateway],
  exports: [WebSocketGateway],
})
export class WebSocketModule {}

