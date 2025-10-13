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

/*
Changer pour une ip privée fixe après les tests
*/
app.listen(PORT, '0.0.0.0', () =>
  console.log(`APP1 listening on http://0.0.0.0:${PORT}`)
);