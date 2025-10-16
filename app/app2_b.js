const express = require('express');
const http = require('http');
const app = express();

// Configuration
const DATA_LAYER = 'http://10.3.0.250:6001';
const PORT = 5001;
const REQUEST_TIMEOUT = 5000;

// Middleware
app.use(express.json());

// Helper function pour les requêtes HTTP avec timeout
function httpGetWithTimeout(url, timeout = REQUEST_TIMEOUT) {
  return new Promise((resolve, reject) => {
    const timer = setTimeout(() => {
      reject(new Error('Request timeout'));
    }, timeout);

    http.get(url, (res) => {
      let data = '';
      res.on('data', chunk => data += chunk);
      res.on('end', () => {
        clearTimeout(timer);
        resolve({ statusCode: res.statusCode, data });
      });
    }).on('error', (err) => {
      clearTimeout(timer);
      reject(err);
    });
  });
}

// Routes
app.get('/whoami', (req, res) => {
  res.json({ 
    instance: 'app-2_b', 
    address: req.socket.localAddress, 
    port: PORT,
    timestamp: new Date().toISOString()
  });
});

app.get('/health', (_, res) => res.send('OK'));

// ============================================================
// Storage Image Endpoint
// ============================================================

// Get App image (from storage account app-vnet, blob container)
app.get('/image/app', async (_, res) => {
  console.log('[INFO] /image/app requested from app-2_b');
  res.setHeader('Content-Type', 'image/jpeg');
  // TODO: Fetch from Azure Storage Account (via private endpoint)
  // For now, return a placeholder or error
  res.status(503).json({ 
    error: 'Storage not yet implemented',
    message: 'Image storage integration pending',
    source: 'Storage Account (App VNet) - Blob Container',
    instance: 'app-2_b'
  });
});

// Proxy vers la couche Data
app.get('/api', async (_, res) => {
  try {
    const result = await httpGetWithTimeout(DATA_LAYER + '/db');
    res.status(result.statusCode).send(result.data);
  } catch (err) {
    console.error(`[ERROR] /api proxy failed: ${err.message}`);
    res.status(502).json({ error: 'Bad Gateway', message: err.message });
  }
});

// Métriques
app.get('/metrics', (_, res) => {
  res.json({
    instance: 'app-2_b',
    port: PORT,
    dataLayer: DATA_LAYER,
    uptime: process.uptime(),
    memory: process.memoryUsage()
  });
});

// Démarrage
app.listen(PORT, '0.0.0.0', () => {
  console.log(`App-2_b listening on 0.0.0.0:${PORT}`);
});
