// Loaded before the npm scripts (node --import). Gives a clear message instead of a cryptic
// "No such built-in module: node:sqlite" when Node.js is too old.
const [major, minor] = process.versions.node.split('.').map(Number);
if (major < 22 || (major === 22 && minor < 13)) {
  console.error(`Node.js ${process.versions.node} is too old for the Ro-Nation bot. Install Node.js 22.13 or newer (the current LTS version from https://nodejs.org), then run "npm install" again.`);
  process.exit(1);
}
