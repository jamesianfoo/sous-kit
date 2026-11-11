# sous-kit

A small React and TypeScript starter for prototyping with AI coding agents, where the design system rules are enforced by the build, not just written down.

## Why

When I built Sous Pantry with Claude Code, rules written in a doc kept eroding. I'd ask the agent to change one title's font size, the build would pass, and every title in the app had changed. sous-kit moves the rules into places an agent can't ignore: the tokens, the component contract and the build.

## How it works

### Three token tiers

`tokens/tokens.jsonc` is the single source of truth.

| Tier | What it holds | Example |
| --- | --- | --- |
| global | Raw values | `navy-900: #162437` |
| alias | Decisions | `text: {global.color.navy-900}` |
| component | Choices for one component | `tile.padding: {global.space.4}` |

`npm run tokens` turns them into CSS custom properties in `src/styles/tokens.css`. References become `var()`, so the browser resolves them. Never edit the generated file.

### The build gate

`npm run build` runs `lint:tokens` first. A raw colour, pixel value or font size in `src/components` or `src/screens` fails the build. Components only use `var(--...)`.

### The component contract

`Tile` shows the pattern:

- Typed props are the contract. A Tile with no title doesn't compile.
- It renders a real `<button>` only when it's interactive (`onSelect`), otherwise a plain element.
- Every state is styled: default, hover, focus-visible, disabled and status.
- The minimum target size comes from a token (WCAG 2.5.8).

### The agent contract

`CLAUDE.md` is what the coding agent reads before it touches anything: tokens only, real buttons and links, every state, run the lint before calling a change done, and only touch the files named in the task.

## Try it

```
npm install
npm run dev
```

To see the gate work, add `color: #ff0000;` to `src/components/Tile/Tile.module.css` and run `npm run build`. It fails.

## Status

One component so far. It's a working example of the pattern, not a full library.
