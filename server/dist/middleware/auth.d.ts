import { Request, Response, NextFunction } from 'express';
import { JwtPayload } from '../services/jwt';
declare global {
    namespace Express {
        interface Request {
            uid: string;
            jwtPayload: JwtPayload;
        }
    }
}
export declare function requireAuth(req: Request, res: Response, next: NextFunction): void;
//# sourceMappingURL=auth.d.ts.map