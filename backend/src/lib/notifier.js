/**
 * Push notifications for things that happen to a team: a coach's new workout
 * or announcement, a private shout-out, a health note for the trainer, a
 * return-to-play step. Text stays short and never names an athlete or a body
 * part — a lock screen is public; the detail is one tap away in the app.
 */
export const PUSH_KINDS = ['assignment', 'announcement', 'shoutout', 'health', 'rtp'];

// Apple's reasons for a token that will never work again.
const DEAD = new Set(['BadDeviceToken', 'Unregistered', 'DeviceTokenNotForTopic']);

export function createNotifier({ prisma, apns = null, log = console }) {
  async function deliver(athleteIds, { kind, title, body, teamId }) {
    const ids = [...new Set(athleteIds)].filter(Boolean);
    if (!apns || ids.length === 0) return 0;
    const devices = await prisma.pushDevice.findMany({ where: { athleteId: { in: ids } } });
    const payload = {
      aps: {
        alert: { title, body },
        sound: 'default',
        'thread-id': teamId ?? kind,
        // Lets the app refresh what the push is about while it is in the background.
        'content-available': 1,
      },
      kind,
      ...(teamId ? { teamId } : {}),
    };
    let sent = 0;
    await Promise.all(devices.filter((d) => !(d.muted ?? []).includes(kind)).map(async (device) => {
      const result = await apns.send(device.token, payload);
      if (result.ok) sent += 1;
      else if (DEAD.has(result.reason) || result.status === 410) {
        await prisma.pushDevice.deleteMany({ where: { token: device.token } });
      } else {
        log.warn?.(`[push] ${kind} not delivered: ${result.status} ${result.reason ?? ''}`);
      }
    }));
    return sent;
  }

  return {
    enabled: Boolean(apns),
    /** Fire and forget: a push failing must never fail the request that caused it. */
    notify(athleteIds, message) {
      return deliver(athleteIds, message).catch((err) => {
        log.warn?.(`[push] ${message.kind} failed: ${err.message}`);
        return 0;
      });
    },
  };
}
