const express = require('express');

const app = express();

app.get('/', (req, res) => {
  res.json({ message: 'Hello from Lab 50', service: 'lab50-ec2-deploy' });
});

app.get('/health', (req, res) => {
  res.status(200).json({ status: 'ok' });
});

app.get('/version', (req, res) => {
  res.json({
    version: process.env.APP_VERSION || 'dev',
    commit: process.env.GIT_SHA || 'unknown',
  });
});

module.exports = app;
