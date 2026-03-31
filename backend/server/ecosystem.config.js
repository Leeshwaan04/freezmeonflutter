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
    },
  ],
};
