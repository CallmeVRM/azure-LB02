const express = require('express');
const http = require('http');
const path = require('path');
const app = express();
const PORT = 7000;

// Static UI
app.use(express.static(__dirname));
app.get('/', (req, res) => res.sendFile(path.join(__dirname, 'index.html')));

// Configuration / inventory
const inventory = {
  frontend: ['10.1.0.4:80', '10.1.0.5:8443'],
  app: ['10.2.0.4:5000', '10.2.0.5:5001'],
  data: ['10.3.0.4:6000', '10.3.0.5:6001']
};

app.get('/status', (_, res) => {
  res.json({ ...inventory, timestamp: new Date().toISOString() });
});

// Helper to probe a single target (whoami and health)
function probeTarget(host, port, pathSuffix, timeout = 3000) {
  return new Promise((resolve) => {
    const opts = {
      host,
      port: parseInt(port, 10),
      path: pathSuffix,
      timeout
    };
    const req = http.get(opts, (r) => {
      let body = '';
      r.on('data', c => body += c);
      r.on('end', () => {
        resolve({ ok: r.statusCode >= 200 && r.statusCode < 300, statusCode: r.statusCode, body });
      });
    });
    req.on('error', () => resolve({ ok: false, error: true }));
    req.on('timeout', () => { req.destroy(); resolve({ ok: false, error: 'timeout' }); });
  });
}

// Probe all inventory and return consolidated results
app.get('/probe', async (_, res) => {
  const result = {};
  for (const [layer, hosts] of Object.entries(inventory)) {
    result[layer] = [];
    for (const h of hosts) {
      const [host, port] = h.split(':');
      const who = await probeTarget(host, port, '/whoami').catch(() => ({ ok: false }));
      const health = await probeTarget(host, port, '/health').catch(() => ({ ok: false }));
      result[layer].push({ host, port, who: who.body || null, whoOk: who.ok, health: health.body || null, healthOk: health.ok });
    }
  }
  result.timestamp = new Date().toISOString();
  res.json(result);
});

app.get('/simulate-failure', (_, res) => {
  res.send('Simulated backend failure. Disable one node manually to observe load balancer reaction.');
});

app.listen(PORT, '10.3.0.10', () =>
  console.log(`Admin portal available at http://10.3.0.10:${PORT}`)
);