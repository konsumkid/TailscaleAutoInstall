import apn from 'apn';
import path from 'path';
import { fileURLToPath } from 'url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));

interface PushPayload {
  [key: string]: string | number | boolean;
}

export class PushService {
  private provider: apn.Provider | null = null;
  private isConfigured: boolean = false;

  constructor() {
    this.initializeProvider();
  }

  private initializeProvider(): void {
    const keyId = process.env.APNS_KEY_ID;
    const teamId = process.env.APNS_TEAM_ID;
    const keyPath = process.env.APNS_KEY_PATH;
    const bundleId = process.env.APNS_BUNDLE_ID;
    const production = process.env.APNS_PRODUCTION === 'true';

    if (!keyId || !teamId || !keyPath || !bundleId) {
      console.warn('APNS not configured - push notifications disabled');
      console.warn('Set APNS_KEY_ID, APNS_TEAM_ID, APNS_KEY_PATH, and APNS_BUNDLE_ID to enable');
      return;
    }

    try {
      const absoluteKeyPath = path.isAbsolute(keyPath)
        ? keyPath
        : path.join(__dirname, '../../', keyPath);

      this.provider = new apn.Provider({
        token: {
          key: absoluteKeyPath,
          keyId,
          teamId
        },
        production
      });

      this.isConfigured = true;
      console.log('APNS provider initialized successfully');
    } catch (error) {
      console.error('Failed to initialize APNS provider:', error);
    }
  }

  async sendNotification(
    deviceToken: string,
    title: string,
    body: string,
    payload?: PushPayload
  ): Promise<boolean> {
    if (!this.isConfigured || !this.provider) {
      console.log('Push notification (mock):', { title, body, payload });
      return true;
    }

    const notification = new apn.Notification();
    notification.alert = { title, body };
    notification.sound = 'default';
    notification.badge = 1;
    notification.topic = process.env.APNS_BUNDLE_ID!;
    notification.payload = payload || {};
    notification.pushType = 'alert';

    try {
      const result = await this.provider.send(notification, deviceToken);

      if (result.failed.length > 0) {
        console.error('Push notification failed:', result.failed);
        return false;
      }

      console.log('Push notification sent successfully');
      return true;
    } catch (error) {
      console.error('Push notification error:', error);
      throw error;
    }
  }

  async sendSilentNotification(
    deviceToken: string,
    payload: PushPayload
  ): Promise<boolean> {
    if (!this.isConfigured || !this.provider) {
      console.log('Silent notification (mock):', payload);
      return true;
    }

    const notification = new apn.Notification();
    notification.contentAvailable = true;
    notification.topic = process.env.APNS_BUNDLE_ID!;
    notification.payload = payload;
    notification.pushType = 'background';

    try {
      const result = await this.provider.send(notification, deviceToken);

      if (result.failed.length > 0) {
        console.error('Silent notification failed:', result.failed);
        return false;
      }

      return true;
    } catch (error) {
      console.error('Silent notification error:', error);
      throw error;
    }
  }

  async sendLiveActivityUpdate(
    pushToken: string,
    contentState: Record<string, unknown>,
    event: 'update' | 'end' = 'update'
  ): Promise<boolean> {
    if (!this.isConfigured || !this.provider) {
      console.log('Live Activity update (mock):', { contentState, event });
      return true;
    }

    const notification = new apn.Notification();
    notification.topic = `${process.env.APNS_BUNDLE_ID}.push-type.liveactivity`;
    notification.pushType = 'liveactivity';
    notification.payload = {
      'aps': {
        'timestamp': Math.floor(Date.now() / 1000),
        'event': event,
        'content-state': contentState
      }
    };
    notification.priority = 10;

    try {
      const result = await this.provider.send(notification, pushToken);

      if (result.failed.length > 0) {
        console.error('Live Activity update failed:', result.failed);
        return false;
      }

      return true;
    } catch (error) {
      console.error('Live Activity update error:', error);
      throw error;
    }
  }

  shutdown(): void {
    if (this.provider) {
      this.provider.shutdown();
    }
  }
}
