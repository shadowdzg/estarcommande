import {
  WebSocketGateway as WSGateway,
  WebSocketServer,
  SubscribeMessage,
  OnGatewayConnection,
  OnGatewayDisconnect,
  ConnectedSocket,
  MessageBody,
} from '@nestjs/websockets';
import { Server, Socket } from 'socket.io';
import { Injectable, Logger } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { CommandeService } from '../commande/commande.service';

@Injectable()
@WSGateway({
  cors: {
    origin: "*",
    methods: ["GET", "POST"]
  },
  namespace: '/'
})
export class WebSocketGateway implements OnGatewayConnection, OnGatewayDisconnect {
  @WebSocketServer()
  server: Server;

  private readonly logger = new Logger(WebSocketGateway.name);
  private readonly connectedClients = new Map<string, { socket: Socket; userId?: string }>();

  constructor(
    private jwtService: JwtService,
    private commandeService: CommandeService,
  ) {}

  async handleConnection(client: Socket) {
    this.logger.log(`Client connected: ${client.id}`);
    
    try {
      // Extract JWT token from auth
      const token = client.handshake.auth?.token;
      
      if (!token) {
        this.logger.warn(`Client ${client.id} connected without token`);
        this.connectedClients.set(client.id, { socket: client });
        return;
      }

      // Verify JWT token
      const payload = this.jwtService.verify(token);
      const userId = payload.sub || payload.id;
      
      this.logger.log(`Client ${client.id} authenticated as user ${userId}`);
      this.connectedClients.set(client.id, { socket: client, userId });
      
      // Join user-specific room for targeted updates
      client.join(`user_${userId}`);
      
      // Send connection confirmation
      client.emit('connectionConfirmed', { 
        message: 'Connected successfully',
        userId: userId 
      });
      
    } catch (error) {
      this.logger.error(`Authentication failed for client ${client.id}:`, error.message);
      this.connectedClients.set(client.id, { socket: client });
    }
  }

  handleDisconnect(client: Socket) {
    this.logger.log(`Client disconnected: ${client.id}`);
    const clientInfo = this.connectedClients.get(client.id);
    
    if (clientInfo?.userId) {
      client.leave(`user_${clientInfo.userId}`);
    }
    
    this.connectedClients.delete(client.id);
  }

  @SubscribeMessage('getCommands')
  async handleGetCommands(
    @ConnectedSocket() client: Socket,
    @MessageBody() data: { page?: number; limit?: number; filters?: any }
  ) {
    try {
      const clientInfo = this.connectedClients.get(client.id);
      
      if (!clientInfo?.userId) {
        client.emit('error', { message: 'Authentication required' });
        return;
      }

      const { page = 1, limit = 10, filters = {} } = data;
      
      // Fetch commands data using the existing service
      const result = await this.commandeService.findAll(filters, { skip: (page - 1) * limit, take: limit });
      
      client.emit('commandsData', {
        data: result.data || [],
        totalCount: result.totalCount || 0,
        page: page,
        limit: limit
      });
      
    } catch (error) {
      this.logger.error(`Error fetching commands for client ${client.id}:`, error.message);
      client.emit('error', { message: 'Failed to fetch commands' });
    }
  }

  @SubscribeMessage('subscribeToCommands')
  async handleSubscribeToCommands(@ConnectedSocket() client: Socket) {
    try {
      const clientInfo = this.connectedClients.get(client.id);
      
      if (!clientInfo?.userId) {
        client.emit('error', { message: 'Authentication required' });
        return;
      }

      // Join commands room for real-time updates
      client.join('commands_updates');
      
      client.emit('subscriptionConfirmed', { 
        message: 'Subscribed to commands updates',
        timestamp: new Date().toISOString()
      });
      
      this.logger.log(`Client ${client.id} subscribed to commands updates`);
      
    } catch (error) {
      this.logger.error(`Error subscribing client ${client.id} to commands:`, error.message);
      client.emit('error', { message: 'Failed to subscribe to commands' });
    }
  }

  @SubscribeMessage('unsubscribeFromCommands')
  async handleUnsubscribeFromCommands(@ConnectedSocket() client: Socket) {
    try {
      // Leave commands room
      client.leave('commands_updates');
      
      client.emit('unsubscriptionConfirmed', { 
        message: 'Unsubscribed from commands updates',
        timestamp: new Date().toISOString()
      });
      
      this.logger.log(`Client ${client.id} unsubscribed from commands updates`);
      
    } catch (error) {
      this.logger.error(`Error unsubscribing client ${client.id} from commands:`, error.message);
      client.emit('error', { message: 'Failed to unsubscribe from commands' });
    }
  }

  // Method to broadcast command updates to all subscribed clients
  async broadcastCommandUpdate(action: 'created' | 'updated' | 'deleted', commandId: string, data?: any) {
    this.server.to('commands_updates').emit('commandUpdated', {
      action,
      commandId,
      data,
      timestamp: new Date().toISOString()
    });
    
    this.logger.log(`Broadcasted command ${action} event for command ${commandId}`);
  }

  // Method to send updates to specific user
  async sendToUser(userId: string, event: string, data: any) {
    this.server.to(`user_${userId}`).emit(event, data);
  }

  // Method to get connected clients count
  getConnectedClientsCount(): number {
    return this.connectedClients.size;
  }

  // Method to get connected users count
  getConnectedUsersCount(): number {
    return Array.from(this.connectedClients.values()).filter(client => client.userId).length;
  }
}
