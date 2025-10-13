const express = require('express');
const http = require('http');
const path = require('path');
const app = express();

const APP_LAYER = 'http://10.2.0.250:5001';
const PORT = 8443;

app.use(express.static(__dirname));
app.get('/', (req, res) => res.sendFile(path.join(__dirname, 'index2.html')));

app.get('/whoami', (req, res) => {
  res.json({ instance: 'frontend-2', address: req.socket.localAddress, port: PORT });
});

app.get('/api', (_, res) => {
  http.get(APP_LAYER + '/api', r => r.pipe(res)).on('error', () => res.status(502).send('Bad Gateway'));
});

app.get('/health', (_, res) => res.send('OK'));

// Server-side probe endpoints
app.get('/probe/app', (_, res) => {
  http.get('http://10.2.0.250:5001/whoami', r => r.pipe(res)).on('error', () => res.status(502).send('ERROR'));
});
app.get('/probe/app-health', (_, res) => {
  http.get('http://10.2.0.250:5001/health', r => r.pipe(res)).on('error', () => res.status(502).send('ERROR'));
});
app.get('/probe/data', (_, res) => {
  http.get('http://10.3.0.250:6000/whoami', r => r.pipe(res)).on('error', () => res.status(502).send(JSON.stringify({ error: 'ERROR' })));
});
app.get('/probe/data-health', (_, res) => {
  http.get('http://10.3.0.250:6000/health', r => r.pipe(res)).on('error', () => res.status(502).send('ERROR'));
});

app.listen(PORT, '10.1.0.5', () =>
  console.log(`Frontend-2 listening on http://10.1.0.5:${PORT}`)
);