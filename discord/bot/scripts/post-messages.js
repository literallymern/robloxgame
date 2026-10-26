// Posts the ready-made messages from discord/messages/*.md and the button panels into their channels.
//
//   npm run post-messages              dry run: lists what would be posted
//   npm run post-messages -- --apply   posts (or, on later runs, edits) the messages
//
// The IDs of posted messages are stored in data/posted-messages.json. Running the script again
// edits those messages instead of posting duplicates (and swaps an attachment whose file changed).
// Nothing is deleted.
import { readFileSync, writeFileSync, existsSync, mkdirSync, statSync } from 'node:fs';
import { join, resolve, dirname, basename } from 'node:path';
import { Client, Events, GatewayIntentBits, AttachmentBuilder } from 'discord.js';
import { config, requireDiscordConfig } from '../src/config.js';
import { CHANNEL_BY_KEY } from '../src/blueprint/channels.js';
import { createResolver } from '../src/discord/ids.js';
import { buildPanel, PANEL_CHANNELS } from '../src/discord/components.js';
import { loadMessages, linkChannels, messagesDir } from '../src/setup/messages.js';

const APPLY = process.argv.includes('--apply');
const stateFile = join(config.root, 'data', 'posted-messages.json');

async function main() {
  const messages = loadMessages();
  const panels = Object.keys(PANEL_CHANNELS);
  console.log(APPLY ? 'Mode: APPLY' : 'Mode: DRY RUN (add --apply to post)');
  for (const m of messages) console.log(`#${CHANNEL_BY_KEY[m.channel].name}: ${m.file} (${m.parts.length} message(s)${m.image ? `, with attachment ${m.image.split('/').pop()}` : ''})`);
  for (const p of panels) console.log(`#${CHANNEL_BY_KEY[PANEL_CHANNELS[p]].name}: button panel "${p}"`);
  if (!APPLY) return;

  requireDiscordConfig();
  const client = new Client({ intents: [GatewayIntentBits.Guilds] });
  await client.login(config.token);
  await new Promise((r) => (client.isReady() ? r() : client.once(Events.ClientReady, r)));
  const state = existsSync(stateFile) ? JSON.parse(readFileSync(stateFile, 'utf8')) : {};
  const save = () => { mkdirSync(dirname(stateFile), { recursive: true }); writeFileSync(stateFile, `${JSON.stringify(state, null, 2)}\n`); };
  try {
    const guild = await client.guilds.fetch(config.guildId);
    const ids = createResolver(config.idsFile);
    await ids.refresh(guild);

    // Posts new messages or edits the ones posted earlier (same key).
    const upsert = async (key, channelKey, payloads) => {
      const channelId = ids.channel(channelKey);
      if (!channelId) throw new Error('channel not found on the server (run "npm run setup-server" first)');
      const channel = await client.channels.fetch(channelId);
      const previous = state[key]?.channelId === channelId ? state[key].messageIds : [];
      const posted = [];
      for (let i = 0; i < payloads.length; i++) {
        const payload = { ...payloads[i], allowedMentions: { parse: [] } };
        const old = previous[i] && await channel.messages.fetch(previous[i]).catch(() => null);
        if (old) {
          const { files, ...edit } = payload;
          // Attachments are uploaded again only when the file changed (other name or size).
          const changed = (files ?? []).some((f) => {
            const sent = old.attachments.find((a) => a.name === basename(f.attachment));
            return !sent || sent.size !== statSync(f.attachment).size;
          });
          await old.edit(changed ? { ...edit, files, attachments: [] } : edit);
          if (changed) console.log(`${key}: attachment replaced`);
          posted.push(old.id);
        } else {
          posted.push((await channel.send(payload)).id);
        }
      }
      if (previous.length > payloads.length) console.warn(`${key}: the text got shorter; delete ${previous.length - payloads.length} old message(s) in #${channel.name} by hand if needed.`);
      state[key] = { channelId, messageIds: posted };
      save();
      console.log(`${previous.length ? 'updated' : 'posted'} ${key} in #${channel.name}`);
    };

    // One failing channel does not stop the others; failures are listed at the end.
    const failures = [];
    const attempt = async (key, channelKey, payloads) => {
      try {
        await upsert(key, channelKey, payloads);
      } catch (err) {
        failures.push(`${key} (#${CHANNEL_BY_KEY[channelKey].name}): ${err.message}`);
        console.error(`FAILED ${key} in #${CHANNEL_BY_KEY[channelKey].name}: ${err.message}`);
      }
    };
    for (const m of messages) {
      const payloads = m.parts.map((content) => ({ content: linkChannels(content, ids) }));
      if (m.image) {
        const file = resolve(messagesDir, m.image);
        if (existsSync(file)) payloads[0].files = [new AttachmentBuilder(file)];
        else console.warn(`${m.file}: attachment ${m.image} not found, posting without it`);
      }
      await attempt(`message:${m.file}`, m.channel, payloads);
    }
    for (const p of panels) await attempt(`panel:${p}`, PANEL_CHANNELS[p], [buildPanel(p, config)]);
    if (failures.length) throw new Error(`${failures.length} message(s) could not be posted:\n  ${failures.join('\n  ')}`);
    console.log('\nAll messages and panels are posted.');
  } finally {
    await client.destroy();
  }
}

main().catch((err) => {
  console.error(`Posting failed: ${err.message}`);
  if (/Missing Access|Missing Permissions/i.test(err.message)) {
    console.error('The bot cannot see or write in that channel. Check that the bot role has View Channels, Send Messages, Embed Links and Attach Files, and run "npm run setup-server" (dry run) to see whether channel permissions differ from the blueprint.');
  }
  process.exit(1);
});
