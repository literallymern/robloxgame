// Generates the reference documents in discord/docs/ from the blueprint and the command
// definitions, so the documentation always matches what the setup script and the bot really do.
//
//   npm run generate-docs
//
// Generated files (do not edit by hand, run this script again instead):
//   docs/01-server-blueprint.md
//   docs/02-role-hierarchy.md
//   docs/03-permission-matrix.md
//   docs/appendix-command-reference.md
import { writeFileSync, mkdirSync } from 'node:fs';
import { resolve } from 'node:path';
import { generatedDocs, docsDir } from '../src/setup/docs.js';

mkdirSync(docsDir, { recursive: true });
for (const [name, text] of Object.entries(generatedDocs())) {
  writeFileSync(resolve(docsDir, name), text);
  console.log(`wrote docs/${name}`);
}
