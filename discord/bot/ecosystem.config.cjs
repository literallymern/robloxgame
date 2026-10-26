// pm2 settings for running the bot in the background and restarting it after a crash.
//   pm2 start ecosystem.config.cjs
// pm2 starts Node directly here (not through npm), so this also works on Windows.
// Keep node_args in line with the "start" script in package.json.
module.exports = {
  apps: [
    {
      name: 'ro-nation',
      cwd: __dirname,
      script: 'src/index.js',
      node_args: '--disable-warning=ExperimentalWarning --import ./src/check-node.js',
      autorestart: true,
      restart_delay: 10000,
      max_restarts: 20,
      kill_timeout: 10000,
    },
  ],
};
