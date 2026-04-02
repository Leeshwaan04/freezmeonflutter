import { Request, Response, NextFunction } from 'express';
/**
 * Idempotency middleware — attach to any mutating endpoint (POST like/skip/send).
 * Client sends `Idempotency-Key: <uuid>` header.
 * First call executes and stores the response; subsequent calls with the same
 * key return the cached response without re-executing.
 */
export declare function idempotent(req: Request, res: Response, next: NextFunction): void;
//# sourceMappingURL=idempotency.d.ts.map