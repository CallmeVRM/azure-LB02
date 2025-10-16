const express = require('express');
const app = express();

// Configuration
const PORT = 6001;
const INSTANCE_NAME = 'data-2';

// Middleware
app.use(express.json());

// Compteur de requêtes pour monitoring
let requestCount = 0;
app.use((req, res, next) => {
  requestCount++;
  console.log(`[${new Date().toISOString()}] ${req.method} ${req.path} - Request #${requestCount}`);
  next();
});

// Routes
app.get('/db', (_, res) => {
  res.json({ 
    message: 'DATA-LAYER-2: OK',
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

// Endpoint de métriques pour monitoring
app.get('/metrics', (_, res) => {
  res.json({
    instance: INSTANCE_NAME,
    port: PORT,
    requests: requestCount,
    uptime: process.uptime(),
    memory: process.memoryUsage(),
    timestamp: new Date().toISOString()
  });
});

// Démarrage du serveur
app.listen(PORT, '0.0.0.0', () => {
  console.log(`
╔════════════════════════════════════════╗
║   Data-2 Server Started                ║
║   Port: ${PORT}                          ║
║   Listening: 0.0.0.0:${PORT}             ║
║   Instance: ${INSTANCE_NAME}                  ║
╚════════════════════════════════════════╝
  `);
});