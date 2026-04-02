import winston from 'winston';

const { combine, timestamp, json, colorize, simple, errors } = winston.format;

const isProd = process.env.NODE_ENV === 'production';

export const logger = winston.createLogger({
  level: isProd ? 'info' : 'debug',
  format: combine(
    errors({ stack: true }),
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
