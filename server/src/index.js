const express = require('express');
const cors = require('cors');
const path = require('path');
const { initDb, purgeUnconfirmedUsers } = require('./db');
const { verifySmtpConnection } = require('./utils/mailer');
const authRoutes = require('./routes/authRoutes');
const bookRoutes = require('./routes/bookRoutes');

require('dotenv').config();

const app = express();
const PORT = process.env.PORT || 3000;

app.use(cors());
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true, limit: '10mb' }));

app.use('/uploads', express.static(path.join(__dirname, '../uploads')));

app.use('/api/auth', authRoutes);
app.use('/api/books', bookRoutes);

app.get('/api/health', (req, res) => {
  res.json({ status: 'ok', service: 'ReadMate Custom REST API', timestamp: new Date() });
});

async function startServer() {
  await initDb();
  await verifySmtpConnection();
  await purgeUnconfirmedUsers();


  setInterval(purgeUnconfirmedUsers, 6 * 60 * 60 * 1000);

  app.listen(PORT, '0.0.0.0', () => {
    console.log(`=================================================`);
    console.log(`ReadMate Custom REST API Server is running!`);
    console.log(`Base URL (Host):     http://localhost:${PORT}/api`);
    console.log(`Base URL (Android):  http://10.0.2.2:${PORT}/api`);
    console.log(`=================================================`);
  });
}

startServer();
