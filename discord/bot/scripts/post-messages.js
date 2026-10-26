// Posts the ready-made messages from discord/messages/*.md and the button panels into their channels.
//
//   npm run post-messages              dry run: lists what would be posted
//   npm run post-messages -- --apply   posts (or, on later runs, edits) the messages
//
// The IDs of posted messages are stored in data/posted-messages.json. Running the script again
// edits those messages instead of posting duplicates. Nothing is deleted.
import { readFileSync, readdirSync, writeFileSync, existsSync, mkdirSync } from 'node:fs';
import { join, resolve, dirname } from 'node:path';
import { Client, Events, GatewayIntentBits, AttachmentBuilder } from 'discord.js';
import { config, requireDiscordConfig } from '../src/config.js';
import { CHANNEL_BY_KEY, CHANNELS } from '../src/blueprint/channels.js';
import { createResolver } from '../src/discord/ids.js';
import { buildPanel, PANEL_CHANNELS } from '../src/discord/components.js';

const APPLY = process.argv.includes('--apply');
const messagesDir = resolve(config.root, '..', 'messages');
const stateFile = join(config.root, 'data', 'posted-messages.json');

// Front matter: lines "key: value" between two "---" lines at the top of the file.
export function parseMessageFile(text) {
  const m = text.match(/^---\r?\n([\s\S]*?)\r?\n---\r?\n([\s\S]*)$/);
  if (!m) throw new Error('Missing front matter (--- channel: ... ---)');
  const meta = Object.fromEntries(m[1].split(/\r?\n/).filter(Boolean).map((l) => {
    const i = l.indexOf(':');
    return [l.slice(0, i).trim(), l.slice(i + 1).trim()];
  }));
  return { meta, body: m[2].trim() };
}

// Splits a long text into Discord messages (max 2,000 characters) at blank lines.
export function splitMessage(text, max = 1800) {
  const parts = [];
  let current = '';
  for (const block of text.split(/\n{2,}/)) {
    const candidate = current ? `${current}\n\n${block}` : block;
    if (candidate.length <= max) { current = candidate; continue; }
    if (current) parts.push(current);
    if (block.length <= max) { current = block; continue; }
    // A single very long block: split by lines.
    current = '';
    for (const line of block.split('\n')) {
      const c2 = current ? `${current}\n${line}` : line;
      if (c2.length <= max) current = c2;
      else { parts.push(current); current = line.slice(0, max); }
    }
  }
  if (current) parts.push(current);
  return parts;
}

// Turns "#channel-name" into a clickable channel link when the channel exists on the server.
export function linkChannels(text, ids) {
  return text.replace(/(^|[\s(*_>])#([a-z0-9-]+)/g, (all, pre, name) => {
    const ch = CHANNELS.find((c) => c.name === name);
    const id = ch && ids.channel(ch.key);
    return id ? `${pre}<#${id}>` : all;
  });
}

export function loadMessages() {
  return readdirSync(messagesDir).filter((f) => f.endsWith('.md') && !f.startsWith('_')).sort().map((file) => {
    const { meta, body } = parseMessageFile(readFileSync(join(messagesDir, file), 'utf8'));
    if (!CHANNEL_BY_KEY[meta.channel]) throw new Error(`${file}: unknown channel key "${meta.channel}"`);
    return { file, channel: meta.channel, order: Number(meta.order ?? 0), image: meta.image ?? null, parts: splitMessage(body) };
  }).sort((a, b) => a.channel.localeCompare(b.channel) || a.order - b.order);
}

async function main() {
  const messages = loadMessages();
  const panels = Object.keys(PANEL_CHANNELS);
  console.log(APPLY ? 'Mode: APPLY' : 'Mode: DRY RUN (add --apply to post)');
  for (const m of messages) console.log(`#${CHANNEL_BY_KEY[m.channel].name}: ${m.file} (${m.parts.length} message(s)${m.image ? ', with image' : ''})`);
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
      if (!channelId) { console.warn(`skip ${key}: channel #${CHANNEL_BY_KEY[channelKey].name} not found`); return; }
      const channel = await client.channels.fetch(channelId);
      const previous = state[key]?.channelId === channelId ? state[key].messageIds : [];
      const posted = [];
      for (let i = 0; i < payloads.length; i++) {
        const payload = { ...payloads[i], allowedMentions: { parse: [] } };
        const old = previous[i] && await channel.messages.fetch(previous[i]).catch(() => null);
        if (old) {
          const { files, ...edit } = payload; // attachments stay as posted the first time
          await old.edit(edit);
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

    for (const m of messages) {
      const payloads = m.parts.map((content) => ({ content: linkChannels(content, ids) }));
      if (m.image) {
        const file = resolve(messagesDir, m.image);
        if (existsSync(file)) payloads[0].files = [new AttachmentBuilder(file)];
        else console.warn(`${m.file}: image ${m.image} not found, posting without it`);
      }
      await upsert(`message:${m.file}`, m.channel, payloads);
    }
    for (const p of panels) await upsert(`panel:${p}`, PANEL_CHANNELS[p], [buildPanel(p, config)]);
  } finally {
    await client.destroy();
  }
}

if (process.argv[1] && resolve(process.argv[1]) === resolve(new URL(import.meta.url).pathname)) {
  main().catch((err) => {
    console.error(`Posting failed: ${err.message}`);
    process.exit(1);
  });
}
