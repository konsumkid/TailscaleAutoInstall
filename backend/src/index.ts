import express from 'express';
import cors from 'cors';
import helmet from 'helmet';
import dotenv from 'dotenv';
import { webhookRouter } from './routes/webhook.js';
import { devicesRouter } from './routes/devices.js';
import { agentsRouter } from './routes/agents.js';
import { healthRouter } from './routes/health.js';
import { errorHandler } from './middleware/errorHandler.js';
import { requestLogger } from './middleware/requestLogger.js';
import { prisma } from './utils/prisma.js';

dotenv.config();

const app = express();
const PORT = process.env.PORT || 3000;

// Middleware
app.use(helmet());
app.use(cors());
app.use(express.json());
app.use(requestLogger);

// Routes
app.use('/api/health', healthRouter);
app.use('/api/webhook', webhookRouter);
app.use('/api/devices', devicesRouter);
app.use('/api/agents', agentsRouter);

// Root route
app.get('/', (req, res) => {
  res.json({
    name: 'Agentfy API',
    version: '1.0.0',
    description: 'Backend for Claude Code Agent Monitor',
    endpoints: {
      health: '/api/health',
      webhook: '/api/webhook/:token',
      devices: '/api/devices',
      agents: '/api/agents'
    }
  });
});

// Error handling
app.use(errorHandler);

// Graceful shutdown
process.on('SIGTERM', async () => {
  console.log('SIGTERM received, shutting down...');
  await prisma.$disconnect();
  process.exit(0);
});

process.on('SIGINT', async () => {
  console.log('SIGINT received, shutting down...');
  await prisma.$disconnect();
  process.exit(0);
});

// Start server
app.listen(PORT, () => {
  console.log(`
  ╔═══════════════════════════════════════════╗
  ║           Agentfy Backend Server          ║
  ╠═══════════════════════════════════════════╣
  ║  Status:  Running                         ║
  ║  Port:    ${PORT}                            ║
  ║  Mode:    ${process.env.NODE_ENV || 'development'}                    ║
  ╚═══════════════════════════════════════════╝
  `);
});

export default app;
