import winston from 'winston';

const { combine, timestamp, json, colorize, simple, errors, format } = winston.format;

const isProd = process.env.NODE_ENV === 'production';

// PII Scrubbing Formatter
const scrubPii = format((info) => {
  const piiKeys = ['email', 'phone', 'password', 'token', 'name', 'ip', 'fcmToken', 'location'];
  
  const scrub = (obj: any) => {
    if (!obj || typeof obj !== 'object') return;
    for (const key of Object.keys(obj)) {
      if (piiKeys.includes(key.toLowerCase()) || piiKeys.includes(key)) {
        obj[key] = '[REDACTED]';
      } else if (typeof obj[key] === 'object') {
        scrub(obj[key]);
      }
    }
  };

  scrub(info);
  return info;
});

export const logger = winston.createLogger({
  level: isProd ? 'info' : 'debug',
  format: combine(
    errors({ stack: true }),
    scrubPii(),
    timestamp(),
    isProd ? json() : combine(colorize(), simple()),
  ),
  transports: [
    new winston.transports.Console(),
    ...(isProd
      ? [
          new winston.transports.File({ filename: '/var/log/freezme/error.log', level: 'error' }),
          new winston.transports.File({ filename: '/var/log/freezme/combined.log' }),
        ]
      : []),
  ],
});

// Replace console.* in production
if (isProd) {
  console.log = (...args) => logger.info(args.join(' '));
  console.error = (...args) => logger.error(args.join(' '));
  console.warn = (...args) => logger.warn(args.join(' '));
}
