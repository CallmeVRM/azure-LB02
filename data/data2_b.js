const express = require('express');
const app = express();

// Configuration
const PORT = 6002;
const INSTANCE_NAME = 'data-2_b';

// Middleware
app.use(express.json());

// Compteur de requêtes
let requestCount = 0;
app.use((req, res, next) => {
  requestCount++;
  console.log(`[${new Date().toISOString()}] ${req.method} ${req.path} - Request #${requestCount}`);
  next();
});

// Routes
app.get('/db', (_, res) => {
  res.json({ 
    message: 'DATA-LAYER-2_B: OK',
    instance: INSTANCE_NAME,
    timestamp: new Date().toISOString()
  });
});

app.get('/whoami', (req, res) => {
  res.json({ 
    instance: INSTANCE_NAME, 
    address: req.socket.localAddress, 
    port: PORT,
    timestamp: new Date().toISOString()
  });
});

app.get('/health', (_, res) => res.send('OK'));

// Métriques
app.get('/metrics', (_, res) => {
  res.json({
    instance: INSTANCE_NAME,
    port: PORT,
    requests: requestCount,
    uptime: process.uptime(),
    memory: process.memoryUsage()
  });
});

// Démarrage
app.listen(PORT, '0.0.0.0', () => {
  console.log(`Data-2_b listening on 0.0.0.0:${PORT}`);
});
