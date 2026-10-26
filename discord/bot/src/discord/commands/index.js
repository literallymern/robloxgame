// All slash commands of the bot.
import player from './player.js';
import business from './business.js';
import finance from './finance.js';
import government from './government.js';
import admin from './admin.js';
import link from './link.js';

export const COMMANDS = [...player, ...business, ...finance, ...government, ...admin, ...link];
export const COMMAND_BY_NAME = new Map(COMMANDS.map((c) => [c.data.name, c]));

export function commandJson() {
  return COMMANDS.map((c) => c.data.toJSON());
}
