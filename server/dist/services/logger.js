"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.logger = void 0;
const winston_1 = __importDefault(require("winston"));
const { combine, timestamp, json, colorize, simple, errors } = winston_1.default.format;
const isProd = process.env.NODE_ENV === 'production';
exports.logger = winston_1.default.createLogger({
    level: isProd ? 'info' : 'debug',
    format: combine(errors({ stack: true }), timestamp(), isProd ? json() : combine(colorize(), simple())),
    transports: [
        new winston_1.default.transports.Console(),
        ...(isProd
            ? [
                new winston_1.default.transports.File({ filename: '/var/log/freezme/error.log', level: 'error' }),
                new winston_1.default.transports.File({ filename: '/var/log/freezme/combined.log' }),
            ]
            : []),
    ],
});
// Replace console.* in production
if (isProd) {
    console.log = (...args) => exports.logger.info(args.join(' '));
    console.error = (...args) => exports.logger.error(args.join(' '));
    console.warn = (...args) => exports.logger.warn(args.join(' '));
}
//# sourceMappingURL=logger.js.map