import { Router } from 'express';
import { prisma } from '../utils/prisma.js';
import { WebhookEventSchema } from '../utils/validators.js';
import { AppError } from '../middleware/errorHandler.js';
import { PushService } from '../services/push.js';
import { AgentStatus } from '@prisma/client';

export const webhookRouter = Router();

const pushService = new PushService();

// Receive webhook events from Claude Code
webhookRouter.post('/:token', async (req, res, next) => {
  try {
    const { token } = req.params;

    // Find device by webhook token
    const device = await prisma.device.findUnique({
      where: { webhookToken: token }
    });

    if (!device) {
      throw new AppError('Invalid webhook token', 401);
    }

    // Validate event payload
    const event = WebhookEventSchema.parse(req.body);

    // Log the event
    await prisma.eventLog.create({
      data: {
        deviceId: device.id,
        agentId: event.agent_id,
        eventType: event.event,
        payload: JSON.stringify(req.body)
      }
    });

    // Process the event
    let agent = null;

    if (event.agent_id) {
      // Find or create agent
      agent = await prisma.agent.upsert({
        where: {
          deviceId_externalId: {
            deviceId: device.id,
            externalId: event.agent_id
          }
        },
        create: {
          deviceId: device.id,
          externalId: event.agent_id,
          name: event.name || `Agent ${event.agent_id.slice(0, 8)}`,
          status: mapEventToStatus(event.event, event.status),
          lastMessage: event.message,
          lastEvent: event.event
        },
        update: {
          name: event.name || undefined,
          status: mapEventToStatus(event.event, event.status),
          lastMessage: event.message || undefined,
          lastEvent: event.event,
          updatedAt: new Date()
        }
      });
    }

    // Send push notification
    const notification = buildNotification(event);
    if (notification) {
      try {
        await pushService.sendNotification(
          device.pushToken,
          notification.title,
          notification.body,
          {
            eventType: event.event,
            agentId: agent?.id || event.agent_id,
            timestamp: new Date().toISOString()
          }
        );
      } catch (pushError) {
        console.error('Push notification failed:', pushError);
        // Don't fail the webhook if push fails
      }
    }

    res.json({
      success: true,
      message: 'Event processed successfully',
      agent: agent ? {
        id: agent.id,
        status: agent.status
      } : null
    });
  } catch (error) {
    next(error);
  }
});

// Test endpoint to verify webhook is working
webhookRouter.get('/:token/test', async (req, res, next) => {
  try {
    const { token } = req.params;

    const device = await prisma.device.findUnique({
      where: { webhookToken: token }
    });

    if (!device) {
      throw new AppError('Invalid webhook token', 401);
    }

    res.json({
      valid: true,
      message: 'Webhook token is valid',
      deviceId: device.id
    });
  } catch (error) {
    next(error);
  }
});

function mapEventToStatus(event: string, explicitStatus?: string): AgentStatus {
  if (explicitStatus) {
    return explicitStatus as AgentStatus;
  }

  switch (event) {
    case 'agent_started':
      return 'RUNNING';
    case 'permission_required':
      return 'AWAITING_INPUT';
    case 'task_completed':
      return 'COMPLETED';
    case 'error':
      return 'ERROR';
    case 'agent_stopped':
      return 'IDLE';
    default:
      return 'RUNNING';
  }
}

function buildNotification(event: { event: string; message?: string; name?: string }): { title: string; body: string } | null {
  switch (event.event) {
    case 'agent_started':
      return {
        title: 'Agent Started',
        body: event.name ? `Session started: ${event.name}` : 'New Claude Code session started'
      };
    case 'permission_required':
      return {
        title: 'Permission Required',
        body: event.message || 'Agent needs your approval to continue'
      };
    case 'task_completed':
      return {
        title: 'Task Completed',
        body: event.message || 'Agent has finished the task successfully'
      };
    case 'error':
      return {
        title: 'Agent Error',
        body: event.message || 'An error occurred in the agent'
      };
    case 'agent_stopped':
      return {
        title: 'Agent Stopped',
        body: event.message || 'Claude Code session has ended'
      };
    case 'heartbeat':
    case 'status_change':
      // Don't send push for heartbeats or status changes
      return null;
    default:
      return null;
  }
}
