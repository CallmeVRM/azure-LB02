const express = require('express');
const http = require('http');
const app = express();

const APP_LAYER = 'http://10.2.0.10:5001';
const PORT = 8443;

app.get('/', (_, res) => res.send('FRONTEND-2: Public Entry via Port 8443'));

app.get('/api', (_, res) => {
  http.get(APP_LAYER + '/api', r => r.pipe(res));
});

app.get('/health', (_, res) => res.send('OK'));

app.listen(PORT, '10.1.0.5', () =>
  console.log(`Frontend-2 listening on http://10.1.0.5:${PORT}`)
);