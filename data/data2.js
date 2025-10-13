const express = require('express');
const app = express();
const PORT = 6001;

app.get('/db', (_, res) => res.send('DATA-LAYER-2: OK'));
app.get('/whoami', (req, res) => res.json({ instance: 'data-2', address: req.socket.localAddress, port: PORT }));
app.get('/health', (_, res) => res.send('OK'));

app.listen(PORT, '0.0.0.0', () =>
  console.log(`DATA2 listening on http://0.0.0.0:${PORT}`)
);