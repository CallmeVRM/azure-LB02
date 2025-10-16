const express = require('express');
const http = require('http');
const app = express();


/*
IP du load balancer data
*/
const DATA_LAYER = 'http://10.3.0.250:6000';
const PORT = 5000;

app.get('/api', (_, res) => http.get(DATA_LAYER + '/db', r => r.pipe(res)).on('error', () => res.status(502).send('Bad Gateway')));
app.get('/whoami', (req, res) => res.json({ instance: 'app-1', address: req.socket.localAddress, port: PORT }));
app.get('/health', (_, res) => res.send('OK'));

// ============================================================
// Storage Image Endpoint
// ============================================================

// Get App image (from storage account app-vnet, blob container)
app.get('/image/app', (_, res) => {
  console.log('[INFO] /image/app requested');
  res.setHeader('Content-Type', 'image/jpeg');
  // TODO: Fetch from Azure Storage Account (via private endpoint)
  // For now, return a placeholder or error
  res.status(503).json({ 
    error: 'Storage not yet implemented',
    message: 'Image storage integration pending',
    source: 'Storage Account (App VNet) - Blob Container',
    instance: 'app-1'
  });
});

// Get metrics
app.get('/metrics', (_, res) => {
  res.json({
    instance: 'app-1',
    port: PORT,
    uptime: process.uptime(),
    memory: process.memoryUsage(),
    timestamp: new Date().toISOString()
  });
});

/*
Changer pour une ip privée fixe après les tests
*/
app.listen(PORT, '0.0.0.0', () =>
  console.log(`APP1 listening on http://0.0.0.0:${PORT}`)
);