import { NestFactory } from '@nestjs/core';
import { AppModule } from './app.module';
import { ValidationPipe } from '@nestjs/common';

async function bootstrap() {
  const app = await NestFactory.create(AppModule);
  
  // Enable CORS for Socket.IO
  app.enableCors({
    origin: '*',
    methods: 'GET,HEAD,PUT,PATCH,POST,DELETE',
    credentials: true,
  });
  
  app.setGlobalPrefix('api/v1');
  app.useGlobalPipes(new ValidationPipe({
    transform: false,
    disableErrorMessages: false,
  }));

  // Get port from environment or default to 8080
  const port = process.env.PORT || 8080;
  
  // Listen on the specified port
  await app.listen(port, '0.0.0.0');
  
  // Signal PM2 that the app is ready (important for cluster mode)
  process.send?.('ready');
  
  console.log(`🚀 NestJS Backend with Socket.IO is running on http://localhost:${port}`);
  console.log(`📡 Socket.IO available at http://localhost:${port}/socket.io/`);
  console.log(`🚀 Running in ${process.env.NODE_ENV || 'development'} mode`);
  console.log(`⚡ Process ID: ${process.pid}`);
}

bootstrap().catch((error) => {
  console.error('❌ Failed to start application:', error);
  process.exit(1);
});