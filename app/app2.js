const express = require('express');
const http = require('http');
const app = express();

// Configuration
const DATA_LAYER = 'http://10.3.0.250:6001';
const PORT = 5001;
const REQUEST_TIMEOUT = 5000; // 5 secondes

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
    instance: 'app-2', 
    address: req.socket.localAddress, 
    port: PORT,
    timestamp: new Date().toISOString()
  });
});

app.get('/health', (_, res) => res.send('OK'));

// Proxy vers la couche Data avec timeout et meilleure gestion d'erreurs
app.get('/api', async (_, res) => {
  try {
    const result = await httpGetWithTimeout(DATA_LAYER + '/db');
    res.status(result.statusCode).send(result.data);
  } catch (err) {
    console.error(`[ERROR] /api proxy to data layer failed: ${err.message}`);
    res.status(502).json({ 
      error: 'Bad Gateway', 
      message: err.message,
      timestamp: new Date().toISOString()
    });
  }
});

// Endpoint de métriques pour monitoring
app.get('/metrics', (_, res) => {
  res.json({
    instance: 'app-2',
    port: PORT,
    dataLayer: DATA_LAYER,
    uptime: process.uptime(),
    memory: process.memoryUsage(),
    timestamp: new Date().toISOString()
  });
});

// Démarrage du serveur
app.listen(PORT, '0.0.0.0', () => {
  console.log(`
╔════════════════════════════════════════╗
║   App-2 Server Started                 ║
║   Port: ${PORT}                          ║
║   Listening: 0.0.0.0:${PORT}             ║
║   Data Layer: ${DATA_LAYER} ║
╚════════════════════════════════════════╝
  `);
});
