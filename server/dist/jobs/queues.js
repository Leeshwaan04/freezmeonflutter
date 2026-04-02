"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.cleanupQueue = exports.pushQueue = exports.expiryQueue = void 0;
exports.scheduleRecurringJobs = scheduleRecurringJobs;
exports.scheduleMeltExpiry = scheduleMeltExpiry;
exports.scheduleBlindExpiry = scheduleBlindExpiry;
exports.scheduleMembershipExpiry = scheduleMembershipExpiry;
exports.enqueuePush = enqueuePush;
const bullmq_1 = require("bullmq");
const client_1 = require("../db/client");
const fcm_1 = require("../services/fcm");
const logger_1 = require("../services/logger");
const connection = { host: '127.0.0.1', port: 6379 };
// ── Queue definitions ────────────────────────────────────────────────────────
exports.expiryQueue = new bullmq_1.Queue('expiry', { connection });
exports.pushQueue = new bullmq_1.Queue('push', { connection });
exports.cleanupQueue = new bullmq_1.Queue('cleanup', { connection });
// ── Expiry worker — melt sessions, blind sessions, memberships ───────────────
new bullmq_1.Worker('expiry', async (job) => {
    const { type } = job.data;
    if (type === 'melt_session') {
        const { sessionId } = job.data;
        await client_1.prisma.meltSession.updateMany({
            where: { id: sessionId, status: 'pending', expiresAt: { lt: new Date() } },
            data: { status: 'expired' },
        });
        logger_1.logger.info({ msg: 'melt_session expired', sessionId });
    }
    if (type === 'blind_session') {
        const { sessionId } = job.data;
        await client_1.prisma.blindsSession.updateMany({
            where: { id: sessionId, phase: { not: 'ended' }, expiresAt: { lt: new Date() } },
            data: { phase: 'ended' },
        });
        logger_1.logger.info({ msg: 'blind_session expired', sessionId });
    }
    if (type === 'membership') {
        const { userId } = job.data;
        const membership = await client_1.prisma.membership.findUnique({ where: { userId } });
        if (membership?.expiry && membership.expiry < new Date()) {
            await client_1.prisma.membership.update({ where: { userId }, data: { active: false } });
            await client_1.prisma.profile.update({ where: { userId }, data: { isPremium: false } });
            logger_1.logger.info({ msg: 'membership expired', userId });
        }
    }
    if (type === 'blinds_queue_cleanup') {
        const deleted = await client_1.prisma.blindsQueue.deleteMany({
            where: { availableUntil: { lt: new Date() } },
        });
        logger_1.logger.info({ msg: 'blinds_queue cleaned', count: deleted.count });
    }
}, { connection, concurrency: 5 });
// ── Push worker — reliable push with retry ───────────────────────────────────
new bullmq_1.Worker('push', async (job) => {
    const { fcmToken, title, body, data } = job.data;
    await (0, fcm_1.sendPushNotification)(fcmToken, title, body, data);
    logger_1.logger.info({ msg: 'push_sent', title });
}, {
    connection,
    concurrency: 10,
});
// ── Cleanup worker — prune old data ─────────────────────────────────────────
new bullmq_1.Worker('cleanup', async (job) => {
    const { type } = job.data;
    if (type === 'expired_tokens') {
        const deleted = await client_1.prisma.refreshToken.deleteMany({
            where: { expiresAt: { lt: new Date() } },
        });
        logger_1.logger.info({ msg: 'expired_tokens_pruned', count: deleted.count });
    }
    if (type === 'old_messages') {
        // Archive messages older than 90 days
        const cutoff = new Date(Date.now() - 90 * 24 * 60 * 60 * 1000);
        const deleted = await client_1.prisma.message.deleteMany({
            where: { createdAt: { lt: cutoff } },
        });
        logger_1.logger.info({ msg: 'old_messages_pruned', count: deleted.count });
    }
}, { connection });
// ── Scheduled recurring jobs ─────────────────────────────────────────────────
async function scheduleRecurringJobs() {
    // Prune expired refresh tokens — every hour
    await exports.cleanupQueue.add('expired_tokens', { type: 'expired_tokens' }, { repeat: { every: 60 * 60 * 1000 }, jobId: 'expired_tokens_hourly' });
    // Clean blinds queue — every 15 minutes
    await exports.expiryQueue.add('blinds_queue_cleanup', { type: 'blinds_queue_cleanup' }, { repeat: { every: 15 * 60 * 1000 }, jobId: 'blinds_queue_cleanup' });
    // Prune old messages — daily at midnight
    await exports.cleanupQueue.add('old_messages', { type: 'old_messages' }, { repeat: { every: 24 * 60 * 60 * 1000 }, jobId: 'old_messages_daily' });
    logger_1.logger.info('[Jobs] recurring jobs scheduled');
}
// ── Helper: schedule expiry for a melt session ───────────────────────────────
async function scheduleMeltExpiry(sessionId, expiresAt) {
    const delay = Math.max(0, expiresAt.getTime() - Date.now());
    await exports.expiryQueue.add('melt_session', { type: 'melt_session', sessionId }, { delay, jobId: `melt_expire_${sessionId}`, attempts: 3, backoff: { type: 'exponential', delay: 5000 } });
}
async function scheduleBlindExpiry(sessionId, expiresAt) {
    const delay = Math.max(0, expiresAt.getTime() - Date.now());
    await exports.expiryQueue.add('blind_session', { type: 'blind_session', sessionId }, { delay, jobId: `blind_expire_${sessionId}`, attempts: 3, backoff: { type: 'exponential', delay: 5000 } });
}
async function scheduleMembershipExpiry(userId, expiresAt) {
    const delay = Math.max(0, expiresAt.getTime() - Date.now());
    await exports.expiryQueue.add('membership', { type: 'membership', userId }, { delay, jobId: `membership_expire_${userId}`, attempts: 3, backoff: { type: 'exponential', delay: 10000 } });
}
async function enqueuePush(fcmToken, title, body, data) {
    await exports.pushQueue.add('push', { fcmToken, title, body, data }, { attempts: 3, backoff: { type: 'exponential', delay: 3000 } });
}
//# sourceMappingURL=queues.js.map