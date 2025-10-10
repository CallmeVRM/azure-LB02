const express = require('express');
const app = express();
const PORT = 6000;

app.get('/db', (_, res) => res.send('DATA-LAYER-1: OK'));
app.get('/health', (_, res) => res.send('OK'));

app.listen(PORT, '10.3.0.4', () =>
  console.log(`DATA1 listening on http://10.3.0.4:${PORT}`)
);