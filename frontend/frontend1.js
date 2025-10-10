const express = require('express');
const http = require('http');
const app = express();

const APP_LAYER = 'http://10.2.0.10:5000'; // Load Balancer App Layer
const PORT = 80;

app.get('/', (_, res) => res.send('FRONTEND-1: Public Entry via Port 80'));

app.get('/api', (_, res) => {
  http.get(APP_LAYER + '/api', r => r.pipe(res));
});

app.get('/health', (_, res) => res.send('OK'));

app.listen(PORT, '10.1.0.4', () =>
  console.log(`Frontend-1 listening on http://10.1.0.4:${PORT}`)
);
