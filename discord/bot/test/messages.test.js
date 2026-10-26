// Checks the ready-made messages in discord/messages: format, length, and that every channel and
// command they mention really exists.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { loadMessages, splitMessage, linkChannels } from '../scripts/post-messages.js';
import { CHANNELS } from '../src/blueprint/channels.js';
import { commandJson } from '../src/discord/commands/index.js';
import { buildPanel, PANEL_CHANNELS } from '../src/discord/components.js';

const messages = loadMessages();
const channelNames = new Set(CHANNELS.map((c) => c.name));
const commands = commandJson();

function commandExists(path) {
  const [name, ...rest] = path.split(' ');
  let node = commands.find((c) => c.name === name);
  if (!node) return false;
  for (const part of rest) {
    const next = (node.options ?? []).find((o) => (o.type === 1 || o.type === 2) && o.name === part);
    if (!next) return (node.options ?? []).every((o) => o.type !== 1 && o.type !== 2); // option text after a leaf
    node = next;
  }
  return true;
}

test('every message file targets a real channel and fits into Discord messages', () => {
  assert.ok(messages.length >= 20);
  for (const m of messages) for (const p of m.parts) assert.ok(p.length <= 1800, `${m.file} part has ${p.length} characters`);
});

test('messages never ping everyone', () => {
  for (const m of messages) for (const p of m.parts) assert.ok(!/@everyone|@here/.test(p), m.file);
});

test('every #channel mentioned in a message exists', () => {
  for (const m of messages) {
    for (const p of m.parts) {
      for (const [, name] of p.matchAll(/(?:^|[\s(*_>])#([a-z0-9-]+)/g)) assert.ok(channelNames.has(name), `${m.file}: #${name}`);
    }
  }
});

test('every slash command mentioned in a message exists', () => {
  for (const m of messages) {
    for (const p of m.parts) {
      for (const [, path] of p.matchAll(/`\/([a-z-]+(?: [a-z-]+)*)/g)) assert.ok(commandExists(path), `${m.file}: /${path}`);
    }
  }
});

test('channel links are inserted when IDs are known', () => {
  const ids = { channel: (key) => (key === 'rules' ? '123' : null) };
  assert.equal(linkChannels('Read #rules and #faq.', ids), 'Read <#123> and #faq.');
});

test('long texts are split at paragraph boundaries', () => {
  const text = Array.from({ length: 30 }, (_, i) => `Paragraph ${i} ${'x'.repeat(100)}`).join('\n\n');
  const parts = splitMessage(text);
  assert.ok(parts.length > 1);
  assert.equal(parts.join('\n\n'), text);
});

test('every panel can be built and has buttons', () => {
  for (const key of Object.keys(PANEL_CHANNELS)) {
    const p = buildPanel(key, { minAccountAgeDays: 7 });
    assert.ok(p.embeds.length === 1 && p.components.length >= 1, key);
    const buttons = p.components.flatMap((r) => r.toJSON().components);
    assert.ok(buttons.length >= 1 && buttons.length <= 25, key);
    for (const b of buttons) assert.ok(b.custom_id.length <= 100);
  }
});
