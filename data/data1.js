const express = require('express');
const app = express();
const PORT = 6000;

app.get('/db', (_, res) => res.send('DATA-LAYER-1: OK'));
app.get('/whoami', (req, res) => res.json({ instance: 'data-1', address: req.socket.localAddress, port: PORT }));
app.get('/health', (_, res) => res.send('OK'));

// ============================================================
// Storage Image Endpoint
// ============================================================

// Get Data image (from storage account data-vnet, blob container)
app.get('/image/data', (_, res) => {
  console.log('[INFO] /image/data requested from data-1');
  res.setHeader('Content-Type', 'image/jpeg');
  // TODO: Fetch from Azure Storage Account (via private endpoint)
  // For now, return a placeholder or error
  res.status(503).json({ 
    error: 'Storage not yet implemented',
    message: 'Image storage integration pending',
    source: 'Storage Account (Data VNet) - Blob Container',
    instance: 'data-1'
  });
});

// Get metrics
app.get('/metrics', (_, res) => {
  res.json({
    instance: 'data-1',
    port: PORT,
    uptime: process.uptime(),
    memory: process.memoryUsage(),
    timestamp: new Date().toISOString()
  });
});

app.listen(PORT, '0.0.0.0', () =>
  console.log(`DATA1 listening on http://0.0.0.0:${PORT}`)
);