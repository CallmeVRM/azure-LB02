const express = require('express');
const http = require('http');
const app = express();

const DATA_LAYER = 'http://10.3.0.10:6001';
const PORT = 5001;

app.get('/api', (_, res) => http.get(DATA_LAYER + '/db', r => r.pipe(res)).on('error', () => res.status(502).send('Bad Gateway')));
app.get('/whoami', (req, res) => res.json({ instance: 'app-2', address: req.socket.localAddress, port: PORT }));
app.get('/health', (_, res) => res.send('OK'));

app.listen(PORT, '10.2.0.5', () =>
  console.log(`APP2 listening on http://10.2.0.5:${PORT}`)
);