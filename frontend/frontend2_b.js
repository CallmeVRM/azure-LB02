const express = require('express');
const http = require('http');
const path = require('path');
const app = express();

// Configuration
const APP_LAYER = 'http://10.2.0.250:5001';
const DATA_LAYER = 'http://10.3.0.250:6001';
const PORT = 8443;
const REQUEST_TIMEOUT = 5000; // 5 secondes

// Middleware
app.use(express.static(__dirname));
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

// Routes principales
app.get('/', (req, res) => res.sendFile(path.join(__dirname, 'index2_b.html')));

app.get('/whoami', (req, res) => {
  res.json({ 
    instance: 'frontend-2_b', 
    address: req.socket.localAddress, 
    port: PORT,
    timestamp: new Date().toISOString()
  });
});

app.get('/health', (_, res) => res.send('OK'));

// Proxy vers la couche App avec timeout
app.get('/api', async (_, res) => {
  try {
    const result = await httpGetWithTimeout(APP_LAYER + '/api');
    res.status(result.statusCode).send(result.data);
  } catch (err) {
    console.error(`[ERROR] /api proxy failed: ${err.message}`);
    res.status(502).json({ error: 'Bad Gateway', message: err.message });
  }
});

// Server-side probe endpoints avec meilleure gestion d'erreurs
app.get('/probe/app', async (_, res) => {
  try {
    const result = await httpGetWithTimeout('http://10.2.0.250:5001/whoami');
    res.setHeader('Content-Type', 'application/json');
    res.send(result.data);
  } catch (err) {
    console.error(`[ERROR] /probe/app failed: ${err.message}`);
    res.status(502).json({ error: err.message });
  }
});

app.get('/probe/app-health', async (_, res) => {
  try {
    const result = await httpGetWithTimeout('http://10.2.0.250:5001/health');
    res.send(result.data);
  } catch (err) {
    console.error(`[ERROR] /probe/app-health failed: ${err.message}`);
    res.status(502).send('ERROR');
  }
});

app.get('/probe/data', async (_, res) => {
  try {
    const result = await httpGetWithTimeout('http://10.3.0.250:6001/whoami');
    res.setHeader('Content-Type', 'application/json');
    res.send(result.data);
  } catch (err) {
    console.error(`[ERROR] /probe/data failed: ${err.message}`);
    res.status(502).json({ error: err.message });
  }
});

app.get('/probe/data-health', async (_, res) => {
  try {
    const result = await httpGetWithTimeout('http://10.3.0.250:6001/health');
    res.send(result.data);
  } catch (err) {
    console.error(`[ERROR] /probe/data-health failed: ${err.message}`);
    res.status(502).send('ERROR');
  }
});

// Endpoint de métriques pour monitoring
app.get('/metrics', (_, res) => {
  res.json({
    instance: 'frontend-2_b',
    port: PORT,
    uptime: process.uptime(),
    memory: process.memoryUsage(),
    timestamp: new Date().toISOString()
  });
});

// Démarrage du serveur sur toutes les interfaces
app.listen(PORT, '0.0.0.0', () => {
  console.log(`
╔════════════════════════════════════════╗
║   Frontend-2 Server Started            ║
║   Port: ${PORT}                          ║
║   Listening: 0.0.0.0:${PORT}             ║
║   App Layer: ${APP_LAYER}  ║
║   Data Layer: ${DATA_LAYER} ║
╚════════════════════════════════════════╝
  `);
});