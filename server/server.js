const express = require('express');
const cors = require('cors');
const path = require('path');
const fs = require('fs');
const semver = require('semver');
const multer = require('multer');

const app = express();
const PORT = process.env.PORT || 3000;

// Middleware
app.use(cors());
app.use(express.json());
app.use(express.static('public'));

// Storage configuration for file uploads
const storage = multer.diskStorage({
  destination: function (req, file, cb) {
    const uploadPath = path.join(__dirname, 'uploads');
    if (!fs.existsSync(uploadPath)) {
      fs.mkdirSync(uploadPath, { recursive: true });
    }
    cb(null, uploadPath);
  },
  filename: function (req, file, cb) {
    cb(null, file.originalname);
  }
});

const upload = multer({ storage: storage });

// Version configuration - this would typically come from a database
let versionConfig = {
  latest: {
    version: '1.0.0',
    buildNumber: 1,
    releaseDate: new Date().toISOString(),
    changelog: [
      'Initial release',
      'Complete purchase order management',
      'Admin panel for product CRUD',
      'WhatsApp integration'
    ],
    platforms: {
      android: {
        downloadUrl: null, // Will be set when APK is uploaded
        fileSize: null,
        minSdkVersion: 21,
        targetSdkVersion: 34
      },
      windows: {
        downloadUrl: null, // Will be set when exe is uploaded
        fileSize: null,
        minWindowsVersion: '10.0.0'
      },
      ios: {
        downloadUrl: null, // App Store URL or enterprise distribution
        fileSize: null,
        minIosVersion: '11.0'
      }
    },
    forceUpdate: false,
    criticalUpdate: false
  },
  minimum: {
    version: '1.0.0',
    buildNumber: 1
  }
};

// API Routes

// Get version information
app.get('/api/version', (req, res) => {
  const { platform, currentVersion, buildNumber } = req.query;
  
  console.log(`Version check requested - Platform: ${platform}, Current: ${currentVersion}, Build: ${buildNumber}`);
  
  try {
    const latest = versionConfig.latest;
    const minimum = versionConfig.minimum;
    
    const currentVersionClean = semver.clean(currentVersion || '0.0.0');
    const latestVersionClean = semver.clean(latest.version);
    const minimumVersionClean = semver.clean(minimum.version);
    
    const hasUpdate = semver.gt(latestVersionClean, currentVersionClean);
    const isForceUpdate = semver.lt(currentVersionClean, minimumVersionClean) || latest.forceUpdate;
    
    const platformInfo = latest.platforms[platform] || {};
    
    const response = {
      hasUpdate,
      isForceUpdate,
      isCriticalUpdate: latest.criticalUpdate,
      latest: {
        version: latest.version,
        buildNumber: latest.buildNumber,
        releaseDate: latest.releaseDate,
        changelog: latest.changelog,
        downloadUrl: platformInfo.downloadUrl,
        fileSize: platformInfo.fileSize,
        platformSpecific: platformInfo
      },
      minimum: {
        version: minimum.version,
        buildNumber: minimum.buildNumber
      }
    };
    
    res.json(response);
  } catch (error) {
    console.error('Error checking version:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Update version configuration (admin endpoint)
app.post('/api/admin/version', (req, res) => {
  const { version, buildNumber, changelog, platforms, forceUpdate, criticalUpdate } = req.body;
  
  try {
    // Validate version format
    if (!semver.valid(version)) {
      return res.status(400).json({ error: 'Invalid version format' });
    }
    
    versionConfig.latest = {
      version,
      buildNumber: parseInt(buildNumber),
      releaseDate: new Date().toISOString(),
      changelog: changelog || [],
      platforms: platforms || versionConfig.latest.platforms,
      forceUpdate: forceUpdate || false,
      criticalUpdate: criticalUpdate || false
    };
    
    // Save to file for persistence
    saveVersionConfig();
    
    res.json({ message: 'Version updated successfully', config: versionConfig.latest });
  } catch (error) {
    console.error('Error updating version:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Upload app binary (admin endpoint)
app.post('/api/admin/upload/:platform', upload.single('app'), (req, res) => {
  const { platform } = req.params;
  const file = req.file;
  
  if (!file) {
    return res.status(400).json({ error: 'No file uploaded' });
  }
  
  const allowedPlatforms = ['android', 'windows', 'ios'];
  if (!allowedPlatforms.includes(platform)) {
    return res.status(400).json({ error: 'Invalid platform' });
  }
  
  try {
    const downloadUrl = `/downloads/${file.filename}`;
    const fileSize = file.size;
    
    // Update version config with download URL
    if (!versionConfig.latest.platforms[platform]) {
      versionConfig.latest.platforms[platform] = {};
    }
    
    versionConfig.latest.platforms[platform].downloadUrl = downloadUrl;
    versionConfig.latest.platforms[platform].fileSize = fileSize;
    
    saveVersionConfig();
    
    res.json({
      message: 'File uploaded successfully',
      downloadUrl,
      fileSize,
      platform
    });
  } catch (error) {
    console.error('Error uploading file:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Download endpoint
app.get('/downloads/:filename', (req, res) => {
  const filename = req.params.filename;
  const filePath = path.join(__dirname, 'uploads', filename);
  
  if (!fs.existsSync(filePath)) {
    return res.status(404).json({ error: 'File not found' });
  }
  
  res.download(filePath);
});

// Get current configuration (admin endpoint)
app.get('/api/admin/config', (req, res) => {
  res.json(versionConfig);
});

// Health check
app.get('/health', (req, res) => {
  res.json({ 
    status: 'OK', 
    timestamp: new Date().toISOString(),
    version: '1.0.0'
  });
});

// Serve admin panel
app.get('/admin', (req, res) => {
  res.sendFile(path.join(__dirname, 'public', 'admin.html'));
});

// Default route
app.get('/', (req, res) => {
  res.json({
    message: 'EST STAR Commande Update Server',
    version: '1.0.0',
    endpoints: {
      version: '/api/version',
      admin: '/admin',
      health: '/health'
    }
  });
});

// Utility functions
function saveVersionConfig() {
  const configPath = path.join(__dirname, 'version-config.json');
  fs.writeFileSync(configPath, JSON.stringify(versionConfig, null, 2));
}

function loadVersionConfig() {
  const configPath = path.join(__dirname, 'version-config.json');
  if (fs.existsSync(configPath)) {
    try {
      const data = fs.readFileSync(configPath, 'utf8');
      versionConfig = JSON.parse(data);
    } catch (error) {
      console.error('Error loading version config:', error);
    }
  }
}

// Load configuration on startup
loadVersionConfig();

// Start server
app.listen(PORT, () => {
  console.log(`EST STAR Commande Update Server running on port ${PORT}`);
  console.log(`Health check: http://localhost:${PORT}/health`);
  console.log(`Admin panel: http://localhost:${PORT}/admin`);
  console.log(`Version API: http://localhost:${PORT}/api/version`);
});

module.exports = app;
