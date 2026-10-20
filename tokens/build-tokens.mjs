import { readFileSync, writeFileSync, mkdirSync } from 'node:fs';

const raw = readFileSync('tokens/tokens.jsonc', 'utf8');
const tokens = JSON.parse(raw.replace(/\/\/.*$/gm, ''));
const lines = [];

// walk the tree; every leaf becomes one CSS custom property
function walk(node, path) {
  for (const [key, value] of Object.entries(node)) {
    const next = [...path, key];
    if (typeof value === 'object') { walk(value, next); continue; }
    const name = '--' + next.join('-');
        // "{alias.color.text}" -> "var(--alias-color-text)"
    const resolved = String(value).replace(
      /\{([^}]+)\}/g,
      (_, ref) => `var(--${ref.replace(/\./g, '-')})`
    );
    lines.push(`  ${name}: ${resolved};`);
  }
}

walk(tokens, []);
mkdirSync('src/styles', { recursive: true });
writeFileSync(
  'src/styles/tokens.css',
  `/* generated from tokens/tokens.json. do not edit. */\n:root {\n${lines.join('\n')}\n}\n`
);
console.log(`wrote ${lines.length} tokens to src/styles/tokens.css`);

