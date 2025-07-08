# EST STAR Commande Update Server

A custom update server for the EST STAR Commande Flutter application, providing version management and app distribution capabilities.

## Features

- **Version Management**: Manage app versions, build numbers, and release notes
- **File Distribution**: Upload and serve app binaries (APK, EXE, IPA)
- **Update Policies**: Support for forced updates and critical updates
- **Multi-platform**: Support for Android, Windows, and iOS
- **Admin Panel**: Web-based administration interface
- **API**: RESTful API for version checking and file distribution

## Setup

### Prerequisites

- Node.js (version 14 or higher)
- npm or yarn

### Installation

1. Navigate to the server directory:
```bash
cd server
```

2. Install dependencies:
```bash
npm install
```

3. Start the server:
```bash
npm start
```

For development with auto-reload:
```bash
npm run dev
```

The server will start on port 3000 by default.

## Configuration

### Environment Variables

- `PORT`: Server port (default: 3000)

### Version Configuration

The server maintains version information in `version-config.json`. This file is automatically created and updated through the admin panel.

## API Endpoints

### Version Check
```
GET /api/version?platform=android&currentVersion=1.0.0&buildNumber=1
```

Response:
```json
{
  "hasUpdate": true,
  "isForceUpdate": false,
  "isCriticalUpdate": false,
  "latest": {
    "version": "1.0.1",
    "buildNumber": 2,
    "releaseDate": "2024-01-01T00:00:00Z",
    "changelog": ["Bug fixes", "Performance improvements"],
    "downloadUrl": "/downloads/app-v1.0.1.apk",
    "fileSize": 12345678
  },
  "minimum": {
    "version": "1.0.0",
    "buildNumber": 1
  }
}
```

### Admin Endpoints

#### Update Version
```
POST /api/admin/version
```

Body:
```json
{
  "version": "1.0.1",
  "buildNumber": 2,
  "changelog": ["Bug fixes", "Performance improvements"],
  "forceUpdate": false,
  "criticalUpdate": false
}
```

#### Upload App Binary
```
POST /api/admin/upload/:platform
```

Form data with file upload.

#### Get Current Configuration
```
GET /api/admin/config
```

## Admin Panel

Access the admin panel at `http://localhost:3000/admin`

Features:
- View current version configuration
- Publish new versions
- Upload app binaries
- Set update policies

## Client Integration

The Flutter app's `UpdateService` is already configured to work with this server. Update the `customUpdateUrl` in the service to point to your server:

```dart
static const String customUpdateUrl = 'https://your-server.com/api/version';
```

## Deployment

### Production Deployment

1. **Environment Setup**:
   - Set `NODE_ENV=production`
   - Configure proper port
   - Set up SSL/HTTPS

2. **Process Management**:
   - Use PM2 or similar process manager
   - Configure auto-restart on crashes

3. **Reverse Proxy**:
   - Use nginx or Apache as reverse proxy
   - Configure SSL termination

4. **File Storage**:
   - Consider using cloud storage (AWS S3, Google Cloud Storage)
   - Implement proper backup strategy

### Example PM2 Configuration

```json
{
  "name": "estarcommande-update-server",
  "script": "server.js",
  "instances": 1,
  "exec_mode": "cluster",
  "env": {
    "NODE_ENV": "production",
    "PORT": 3000
  }
}
```

### Example Nginx Configuration

```nginx
server {
    listen 80;
    server_name your-domain.com;

    location / {
        proxy_pass http://localhost:3000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_cache_bypass $http_upgrade;
    }

    # Static file serving for downloads
    location /downloads/ {
        alias /path/to/server/uploads/;
        expires 1y;
        add_header Cache-Control "public, immutable";
    }
}
```

## Security Considerations

1. **Authentication**: Implement proper authentication for admin endpoints
2. **File Validation**: Validate uploaded files for security
3. **Rate Limiting**: Implement rate limiting to prevent abuse
4. **HTTPS**: Use HTTPS in production
5. **Input Validation**: Validate all input data
6. **File Size Limits**: Set appropriate file size limits

## Monitoring

- Monitor server logs for errors
- Set up health checks
- Monitor disk space for uploaded files
- Track API usage and performance

## Support

For issues or questions, please refer to the main application documentation or contact the development team.
