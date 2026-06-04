import winston from 'winston';

// `winston.format` is itself the formatter factory; the named combinators hang
// off it. Destructuring `format` from it is wrong (there is no
// winston.format.format) — capture the factory separately.
const formatFactory = winston.format;
const { combine, timestamp, json, colorize, simple, errors } = winston.format;

const isProd = process.env.NODE_ENV === 'production';

// PII Scrubbing Formatter — redacts sensitive keys before anything is written.
const scrubPii = formatFactory((info) => {
  const piiKeys = ['email', 'phone', 'password', 'token', 'name', 'ip', 'fcmToken', 'location'];

  const scrub = (obj: unknown): void => {
    if (!obj || typeof obj !== 'object') return;
    const record = obj as Record<string, unknown>;
    for (const key of Object.keys(record)) {
      if (piiKeys.includes(key.toLowerCase()) || piiKeys.includes(key)) {
        record[key] = '[REDACTED]';
      } else if (typeof record[key] === 'object') {
        scrub(record[key]);
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
