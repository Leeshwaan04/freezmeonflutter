module.exports = {
  apps: [
    {
      name: 'freezme-api',
      script: './dist/index.js',
      instances: 'max',        // one per CPU core
      exec_mode: 'cluster',
      watch: false,
      env: {
        NODE_ENV: 'production',
        PORT: 3000,
      },
      error_file: '/var/log/freezme/error.log',
      out_file: '/var/log/freezme/out.log',
      log_date_format: 'YYYY-MM-DD HH:mm:ss',
      max_memory_restart: '512M',
      // Graceful shutdown: give in-flight requests 10s to complete before SIGKILL
      kill_timeout: 10000,
      // How long PM2 waits for the app to start listening before considering it failed
      listen_timeout: 5000,
      // Trigger graceful shutdown via SIGTERM (default — explicit for clarity)
      shutdown_with_message: false,
    },
  ],
};
