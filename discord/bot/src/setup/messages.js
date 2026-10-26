// Reads the ready-made messages from discord/messages/*.md. Used by scripts/post-messages.js and the tests.
import { readFileSync, readdirSync } from 'node:fs';
import { join, resolve } from 'node:path';
import { config } from '../config.js';
import { CHANNEL_BY_KEY, CHANNELS } from '../blueprint/channels.js';

export const messagesDir = resolve(config.root, '..', 'messages');

// Front matter: lines "key: value" between two "---" lines at the top of the file.
export function parseMessageFile(text) {
  const m = text.match(/^---\r?\n([\s\S]*?)\r?\n---\r?\n([\s\S]*)$/);
  if (!m) throw new Error('Missing front matter (--- channel: ... ---)');
  const meta = Object.fromEntries(m[1].split(/\r?\n/).filter(Boolean).map((l) => {
    const i = l.indexOf(':');
    return [l.slice(0, i).trim(), l.slice(i + 1).trim()];
  }));
  return { meta, body: m[2].replace(/\r\n/g, '\n').trim() };
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
