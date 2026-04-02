import { Queue } from 'bullmq';
export declare const expiryQueue: Queue<any, any, string, any, any, string>;
export declare const pushQueue: Queue<any, any, string, any, any, string>;
export declare const cleanupQueue: Queue<any, any, string, any, any, string>;
export declare function scheduleRecurringJobs(): Promise<void>;
export declare function scheduleMeltExpiry(sessionId: string, expiresAt: Date): Promise<void>;
export declare function scheduleBlindExpiry(sessionId: string, expiresAt: Date): Promise<void>;
export declare function scheduleMembershipExpiry(userId: string, expiresAt: Date): Promise<void>;
export declare function enqueuePush(fcmToken: string, title: string, body: string, data?: Record<string, string>): Promise<void>;
//# sourceMappingURL=queues.d.ts.map