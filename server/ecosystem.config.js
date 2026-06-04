// PM2 process topology.
//
// Two processes by design:
//   • freezme-api    — HTTP + WebSocket. Runs in fork mode (single process on
//     this 2-vCPU box; local Redis + Socket.IO make cluster mode low-value here).
//     DISABLE_WORKERS=true so it NEVER runs BullMQ workers/crons.
//   • freezme-worker — owns ALL BullMQ workers + the recurring-job scheduler,
//     exactly once. This is the only process that should run jobs; see the
//     RUN_WORKERS guard in src/jobs/queues.ts.
//
// To scale the API horizontally later: raise `instances` (needs shared Redis /
// ElastiCache — local Redis won't work across boxes) and keep ONE worker.
module.exports = {
  apps: [
    {
      name: 'freezme-api',
      script: './dist/index.js',
      instances: 1,
      exec_mode: 'fork',
      watch: false,
      env: {
        NODE_ENV: 'production',
        PORT: 3000,
        DISABLE_WORKERS: 'true', // API process must not run cron/queue workers
      },
      error_file: '/var/log/freezme/error.log',
      out_file: '/var/log/freezme/out.log',
      log_date_format: 'YYYY-MM-DD HH:mm:ss',
      max_memory_restart: '512M',
      kill_timeout: 10000,   // 10s for in-flight requests before SIGKILL
      listen_timeout: 5000,
      shutdown_with_message: false,
    },
    {
      name: 'freezme-worker',
      script: './dist/index.js',
      instances: 1,
      exec_mode: 'fork',
      watch: false,
      env: {
        NODE_ENV: 'production',
        PORT: 3001,            // separate port; not behind the ALB
        // workers enabled (RUN_WORKERS defaults on when DISABLE_WORKERS!=='true')
      },
      error_file: '/var/log/freezme/worker-error.log',
      out_file: '/var/log/freezme/worker-out.log',
      log_date_format: 'YYYY-MM-DD HH:mm:ss',
      max_memory_restart: '400M',
      kill_timeout: 15000,   // give in-flight jobs longer to finish
      listen_timeout: 8000,
    },
  ],
};
