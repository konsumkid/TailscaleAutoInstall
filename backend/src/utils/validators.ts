import { z } from 'zod';

export const WebhookEventSchema = z.object({
  event: z.enum([
    'agent_started',
    'status_change',
    'permission_required',
    'task_completed',
    'error',
    'agent_stopped',
    'heartbeat'
  ]),
  agent_id: z.string().optional(),
  status: z.enum(['IDLE', 'RUNNING', 'AWAITING_INPUT', 'COMPLETED', 'ERROR']).optional(),
  message: z.string().optional(),
  name: z.string().optional(),
  timestamp: z.string().optional(),
});

export const DeviceRegistrationSchema = z.object({
  pushToken: z.string().min(1, 'Push token is required'),
  platform: z.enum(['ios', 'macos']).default('ios'),
  appVersion: z.string().optional(),
});

export const DeviceUpdateSchema = z.object({
  pushToken: z.string().min(1).optional(),
  appVersion: z.string().optional(),
});

export type WebhookEvent = z.infer<typeof WebhookEventSchema>;
export type DeviceRegistration = z.infer<typeof DeviceRegistrationSchema>;
export type DeviceUpdate = z.infer<typeof DeviceUpdateSchema>;
