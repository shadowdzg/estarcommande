# PM2 Setup for NestJS Backend

## Current Status
✅ **Your NestJS backend is now running under PM2!**

- **Process Name**: nestjs-backend
- **PM2 ID**: 2
- **Status**: Online
- **Memory Usage**: ~124MB
- **API URL**: http://localhost:3000/api/v1

## Current PM2 Processes
```
┌────┬────────────────────┬──────────┬──────┬───────────┬──────────┬──────────┐
│ id │ name               │ mode     │ ↺    │ status    │ cpu      │ memory   │
├────┼────────────────────┼──────────┼──────┼───────────┼──────────┼──────────┤
│ 0  │ flexy-server       │ fork     │ 961  │ errored   │ 0%       │ 0b       │
│ 2  │ nestjs-backend     │ cluster  │ 0    │ online    │ 0%       │ 124.3mb  │
│ 1  │ telegram-recharge… │ cluster  │ 0    │ online    │ 0%       │ 53.6mb   │
└────┴────────────────────┴──────────┴──────┴───────────┴──────────┴──────────┘
```

## Available API Endpoints
- **Authentication**: `/api/v1/auth/login`, `/api/v1/auth/register`
- **Users**: `/api/v1/users`
- **Clients**: `/api/v1/clients`
- **Commands**: `/api/v1/commands`
- **Products**: `/api/v1/products`
- **Fournisseurs**: `/api/v1/fournisseurs`
- **Zones**: `/api/v1/zones`

## PM2 Commands

### Basic Commands
```bash
# View all processes
pm2 list

# View logs
pm2 logs nestjs-backend

# Restart the backend
pm2 restart nestjs-backend

# Stop the backend
pm2 stop nestjs-backend

# Delete the backend process
pm2 delete nestjs-backend

# View process info
pm2 info nestjs-backend
```

### Monitoring
```bash
# Real-time monitoring
pm2 monit

# View logs in real-time
pm2 logs nestjs-backend --follow
```

## Windows Auto-Start Setup

Since PM2 startup doesn't work natively on Windows, here are the options:

### Option 1: Windows Task Scheduler (Recommended)
1. Open **Task Scheduler** (taskschd.msc)
2. Click **Create Basic Task**
3. Name: "Start PM2 Processes"
4. Trigger: **When the computer starts**
5. Action: **Start a program**
6. Program: `C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe`
7. Arguments: `-ExecutionPolicy Bypass -File "D:\downloads\backup\backup\start-pm2.ps1"`

### Option 2: Startup Folder
1. Copy `start-pm2.bat` to your Windows Startup folder
2. Press `Win + R`, type `shell:startup`, press Enter
3. Copy the batch file there

### Option 3: Registry (Advanced)
Add a registry entry to run the script on startup.

## Files Created
- `ecosystem.config.js` - PM2 configuration
- `start-pm2.bat` - Windows batch startup script
- `start-pm2.ps1` - PowerShell startup script
- `logs/` - Directory for PM2 logs

## Environment Variables
The backend uses these environment variables (configured in ecosystem.config.js):
- `DATABASE_URL`: MySQL connection string
- `JWT_EXPIRY`: JWT token expiration (1d)
- `JWT_SECRET`: JWT secret key

## Database
✅ **Database preserved** - No data was lost or modified
✅ **Schema introspected** - Prisma schema generated from existing database
✅ **6 models found**: clients, commands, fournisseurs, products, users, zones

## Troubleshooting

### If the backend stops:
```bash
pm2 restart nestjs-backend
```

### If PM2 doesn't start after reboot:
1. Run the startup script manually: `.\start-pm2.ps1`
2. Check if Node.js and PM2 are in your PATH
3. Verify the project directory exists

### View error logs:
```bash
pm2 logs nestjs-backend --err
```

## Success! 🎉
Your NestJS backend is now:
- ✅ Running under PM2 process manager
- ✅ Configured to auto-restart on crashes
- ✅ Connected to your existing MySQL database
- ✅ All API endpoints are working
- ✅ Logs are being captured
- ✅ Ready for production use

