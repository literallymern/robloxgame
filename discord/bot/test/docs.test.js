import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { resolve } from 'node:path';
import { generatedDocs, docsDir } from '../scripts/generate-docs.js';

test('generated documentation matches the blueprint (run "npm run generate-docs" after changes)', () => {
  for (const [name, text] of Object.entries(generatedDocs())) {
    assert.equal(readFileSync(resolve(docsDir, name), 'utf8'), text, `docs/${name} is out of date`);
  }
});
