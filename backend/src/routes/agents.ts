import { Router } from 'express';
import { prisma } from '../utils/prisma.js';
import { AppError } from '../middleware/errorHandler.js';

export const agentsRouter = Router();

// Get all agents for a device (by webhook token)
agentsRouter.get('/by-token/:webhookToken', async (req, res, next) => {
  try {
    const device = await prisma.device.findUnique({
      where: { webhookToken: req.params.webhookToken },
      include: {
        agents: {
          orderBy: { updatedAt: 'desc' }
        }
      }
    });

    if (!device) {
      throw new AppError('Device not found', 404);
    }

    res.json({
      agents: device.agents,
      count: device.agents.length
    });
  } catch (error) {
    next(error);
  }
});

// Get all agents for a device (by device ID)
agentsRouter.get('/by-device/:deviceId', async (req, res, next) => {
  try {
    const agents = await prisma.agent.findMany({
      where: { deviceId: req.params.deviceId },
      orderBy: { updatedAt: 'desc' }
    });

    res.json({
      agents,
      count: agents.length
    });
  } catch (error) {
    next(error);
  }
});

// Get a specific agent
agentsRouter.get('/:id', async (req, res, next) => {
  try {
    const agent = await prisma.agent.findUnique({
      where: { id: req.params.id }
    });

    if (!agent) {
      throw new AppError('Agent not found', 404);
    }

    res.json(agent);
  } catch (error) {
    next(error);
  }
});

// Delete an agent
agentsRouter.delete('/:id', async (req, res, next) => {
  try {
    const agent = await prisma.agent.findUnique({
      where: { id: req.params.id }
    });

    if (!agent) {
      throw new AppError('Agent not found', 404);
    }

    await prisma.agent.delete({
      where: { id: req.params.id }
    });

    res.json({
      message: 'Agent deleted successfully'
    });
  } catch (error) {
    next(error);
  }
});

// Clear all agents for a device
agentsRouter.delete('/by-device/:deviceId/all', async (req, res, next) => {
  try {
    const device = await prisma.device.findUnique({
      where: { id: req.params.deviceId }
    });

    if (!device) {
      throw new AppError('Device not found', 404);
    }

    const result = await prisma.agent.deleteMany({
      where: { deviceId: req.params.deviceId }
    });

    res.json({
      message: 'All agents cleared successfully',
      deletedCount: result.count
    });
  } catch (error) {
    next(error);
  }
});

// Get agent statistics
agentsRouter.get('/by-device/:deviceId/stats', async (req, res, next) => {
  try {
    const stats = await prisma.agent.groupBy({
      by: ['status'],
      where: { deviceId: req.params.deviceId },
      _count: { status: true }
    });

    const statusCounts = stats.reduce((acc, item) => {
      acc[item.status] = item._count.status;
      return acc;
    }, {} as Record<string, number>);

    const total = await prisma.agent.count({
      where: { deviceId: req.params.deviceId }
    });

    res.json({
      total,
      byStatus: {
        idle: statusCounts['IDLE'] || 0,
        running: statusCounts['RUNNING'] || 0,
        awaitingInput: statusCounts['AWAITING_INPUT'] || 0,
        completed: statusCounts['COMPLETED'] || 0,
        error: statusCounts['ERROR'] || 0
      }
    });
  } catch (error) {
    next(error);
  }
});
