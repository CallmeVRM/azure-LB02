const express = require('express');
const app = express();
const PORT = 7000;

app.get('/', (_, res) => {
  res.send(`
    <h2>Azure Multi-Layer Lab - Admin Portal</h2>
    <ul>
      <li><a href="/status">System Status</a></li>
      <li><a href="/simulate-failure">Simulate Failure</a></li>
    </ul>
  `);
});

app.get('/status', (_, res) => {
  res.json({
    frontend: ['10.1.0.4:80', '10.1.0.5:8443'],
    app: ['10.2.0.4:5000', '10.2.0.5:5001'],
    data: ['10.3.0.4:6000', '10.3.0.5:6001'],
    timestamp: new Date().toISOString()
  });
});

app.get('/simulate-failure', (_, res) => {
  res.send('Simulated backend failure. Disable one node manually to observe load balancer reaction.');
});

app.listen(PORT, '10.3.0.10', () =>
  console.log(`Admin portal available at http://10.3.0.10:${PORT}`)
);