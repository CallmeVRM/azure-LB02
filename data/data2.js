const express = require('express');
const app = express();
const PORT = 6001;

app.get('/db', (_, res) => res.send('DATA-LAYER-2: OK'));
app.get('/health', (_, res) => res.send('OK'));

app.listen(PORT, '10.3.0.5', () =>
  console.log(`DATA2 listening on http://10.3.0.5:${PORT}`)
);