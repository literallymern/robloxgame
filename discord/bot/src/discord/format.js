// Small helpers for Discord replies.
import { MessageFlags } from 'discord.js';
import { formatKGD } from '../economy/money.js';

export const COLORS = { info: 0x2e86c1, ok: 0x27ae60, warn: 0xe67e22, error: 0xc0392b, gov: 0x8b0000, avk: 0x229954, econ: 0x1f6f43 };

export function embed({ title, description = null, color = COLORS.info, fields = [], footer = null }) {
  const e = { title: String(title).slice(0, 256), color };
  if (description) e.description = String(description).slice(0, 4096);
  if (fields.length) e.fields = fields.slice(0, 25).map((f) => ({ name: String(f.name).slice(0, 256), value: String(f.value || '-').slice(0, 1024), inline: !!f.inline }));
  if (footer) e.footer = { text: String(footer).slice(0, 2048) };
  return e;
}

// Private reply (only the user who ran the command can see it).
export async function reply(interaction, payload, { ephemeral = true } = {}) {
  const body = typeof payload === 'string' ? { content: payload } : payload;
  const data = { ...body, flags: ephemeral ? MessageFlags.Ephemeral : undefined, allowedMentions: { parse: [] } };
  if (interaction.deferred || interaction.replied) return interaction.followUp(data);
  return interaction.reply(data);
}

export const user = (id) => `<@${id}>`;
export const money = formatKGD;

export function lines(rows, empty = 'Nothing to show.') {
  return rows.length ? rows.join('\n').slice(0, 4000) : empty;
}
