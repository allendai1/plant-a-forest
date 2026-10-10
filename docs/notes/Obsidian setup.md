# Obsidian setup

Set up 2026-10-09.

- The project folder is the Obsidian vault. This folder, `docs/notes/`, is the notebook shared with Claude.
- **Claude reads [Index](Index.md) at the start of every session**, checks for notes that aren't in the index yet, and writes here when you ask it to note or remember something. The instruction is in the project's `CLAUDE.md` and in Claude's own memory.
- The doc references across `docs/`, `CLAUDE.md` and `START_HERE.md` are now real Markdown links (about 105), so clicking, the graph view and backlinks work. They also work on GitHub.
- `.obsidian/workspace.json` (your open tabs) is in `.gitignore`; your vault settings will be committed with everything else.
- Recommended Obsidian settings (Settings → Files & links): turn off "Use [[Wikilinks]]", set the link format to relative paths, and exclude `src`, `tools`, `.luau-lsp` and `assets`.
- Claude's own memory (how you like to work, such as "never spend Robux") lives separately in `C:\Users\Allen\.claude\projects\C--Users-Allen-Downloads-plant-the-forest-handoff\memory`, which can be opened as a second vault.
