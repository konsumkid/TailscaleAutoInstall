import { Router } from 'express';
import { prisma } from '../utils/prisma.js';
import { DeviceRegistrationSchema, DeviceUpdateSchema } from '../utils/validators.js';
import { AppError } from '../middleware/errorHandler.js';

export const devicesRouter = Router();

// Register a new device
devicesRouter.post('/register', async (req, res, next) => {
  try {
    const data = DeviceRegistrationSchema.parse(req.body);

    // Check if device already exists with this push token
    const existingDevice = await prisma.device.findUnique({
      where: { pushToken: data.pushToken }
    });

    if (existingDevice) {
      // Update existing device
      const updated = await prisma.device.update({
        where: { id: existingDevice.id },
        data: {
          appVersion: data.appVersion,
          updatedAt: new Date()
        }
      });

      res.json({
        id: updated.id,
        webhookToken: updated.webhookToken,
        webhookUrl: `${req.protocol}://${req.get('host')}/api/webhook/${updated.webhookToken}`,
        message: 'Device updated successfully'
      });
      return;
    }

    // Create new device
    const device = await prisma.device.create({
      data: {
        pushToken: data.pushToken,
        platform: data.platform,
        appVersion: data.appVersion
      }
    });

    res.status(201).json({
      id: device.id,
      webhookToken: device.webhookToken,
      webhookUrl: `${req.protocol}://${req.get('host')}/api/webhook/${device.webhookToken}`,
      message: 'Device registered successfully'
    });
  } catch (error) {
    next(error);
  }
});

// Get device info
devicesRouter.get('/:id', async (req, res, next) => {
  try {
    const device = await prisma.device.findUnique({
      where: { id: req.params.id },
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
      id: device.id,
      webhookToken: device.webhookToken,
      webhookUrl: `${req.protocol}://${req.get('host')}/api/webhook/${device.webhookToken}`,
      platform: device.platform,
      appVersion: device.appVersion,
      createdAt: device.createdAt,
      agents: device.agents
    });
  } catch (error) {
    next(error);
  }
});

// Update device
devicesRouter.patch('/:id', async (req, res, next) => {
  try {
    const data = DeviceUpdateSchema.parse(req.body);

    const device = await prisma.device.findUnique({
      where: { id: req.params.id }
    });

    if (!device) {
      throw new AppError('Device not found', 404);
    }

    const updated = await prisma.device.update({
      where: { id: req.params.id },
      data
    });

    res.json({
      id: updated.id,
      webhookToken: updated.webhookToken,
      message: 'Device updated successfully'
    });
  } catch (error) {
    next(error);
  }
});

// Unregister device
devicesRouter.delete('/:id', async (req, res, next) => {
  try {
    const device = await prisma.device.findUnique({
      where: { id: req.params.id }
    });

    if (!device) {
      throw new AppError('Device not found', 404);
    }

    await prisma.device.delete({
      where: { id: req.params.id }
    });

    res.json({
      message: 'Device unregistered successfully'
    });
  } catch (error) {
    next(error);
  }
});

// Regenerate webhook token
devicesRouter.post('/:id/regenerate-token', async (req, res, next) => {
  try {
    const device = await prisma.device.findUnique({
      where: { id: req.params.id }
    });

    if (!device) {
      throw new AppError('Device not found', 404);
    }

    const { v4: uuidv4 } = await import('uuid');

    const updated = await prisma.device.update({
      where: { id: req.params.id },
      data: {
        webhookToken: uuidv4()
      }
    });

    res.json({
      webhookToken: updated.webhookToken,
      webhookUrl: `${req.protocol}://${req.get('host')}/api/webhook/${updated.webhookToken}`,
      message: 'Webhook token regenerated successfully'
    });
  } catch (error) {
    next(error);
  }
});
