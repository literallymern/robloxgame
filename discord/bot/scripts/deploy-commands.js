// Registers the slash commands on your server. Run it once after setup and again after updates.
//   npm run deploy-commands
//   npm run deploy-commands -- --dry-run     (only prints the command list)
import { REST, Routes } from 'discord.js';
import { config, requireDiscordConfig } from '../src/config.js';
import { commandJson } from '../src/discord/commands/index.js';

const body = commandJson();
console.log(`${body.length} commands: ${body.map((c) => `/${c.name}`).join(' ')}`);
if (process.argv.includes('--dry-run')) process.exit(0);

requireDiscordConfig();
const rest = new REST().setToken(config.token);
try {
  const result = await rest.put(Routes.applicationGuildCommands(config.clientId, config.guildId), { body });
  console.log(`Registered ${result.length} commands on server ${config.guildId}. They are available immediately.`);
} catch (err) {
  console.error(`Registering commands failed: ${err.message}`);
  console.error('Check DISCORD_TOKEN, DISCORD_CLIENT_ID and DISCORD_GUILD_ID in .env, and that the bot was invited with the "applications.commands" scope.');
  process.exit(1);
}
