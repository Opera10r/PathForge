# PathForge

**Right-click any file or folder in macOS Finder. Copy its path in the exact format you need.**

Seven path formats. One right-click. The path utility for terminal devs.

## The Problem

macOS Finder can copy file paths (`Option+Cmd+C`), but only as absolute POSIX paths. Developers need:

- **Git-relative paths** for Claude Code prompts (`src/components/Header.tsx`)
- **Shell-escaped paths** for terminals with spaces (`/Users/me/My\ Projects/app`)
- **Quoted paths** for scripts (`"/Users/me/My Projects/app"`)
- **`cd` commands** they can paste directly

PathForge gives you every format in one right-click.

## Formats

| Format | Example | Use Case |
|--------|---------|----------|
| Absolute | `/Users/dev/projects/app/src/App.tsx` | General purpose |
| Shell-Escaped | `/Users/dev/My\ Projects/app/src/App.tsx` | Terminal with spaces |
| Git-Relative | `src/App.tsx` | Claude Code, AI tools, git |
| Quoted | `"/Users/dev/My Projects/app/src/App.tsx"` | Shell scripts, JSON |
| cd Command | `cd /Users/dev/projects/app/src` | Paste into terminal |
| File URL | `file:///Users/dev/projects/app/src/App.tsx` | Browsers, docs |
| All Formats | All 6 above, labeled | When you're not sure |

## Install

```bash
git clone https://github.com/opera10r/PathForge.git
cd PathForge
./install.sh
```

After install, right-click any file in Finder → **Quick Actions** → pick a PathForge format.

If the actions don't appear, go to **System Settings → Privacy & Security → Extensions → Finder Extensions** and enable them.

## Uninstall

```bash
cd PathForge
./uninstall.sh
```

## Features

- **Git-aware**: Automatically detects git repos and computes relative paths from the repo root
- **Multi-file**: Select multiple files, right-click, get all paths (one per line)
- **Instant**: Pure shell script — no app to launch, no dependencies to install
- **Notifications**: Visual confirmation of what was copied

## Pricing

- **Free**: 3 copies per day
- **Unlimited**: [$1/month](https://buy.stripe.com/dRmfZg4YO4hO2I84vA2cg01)

To activate after purchase:

```bash
pathforge activate <your_license_key>
```

Check your status anytime:

```bash
pathforge status
```

## Requirements

- macOS 13+ (Ventura or later)
- Git (for git-relative paths — ships with Xcode Command Line Tools)

## License

MIT

---

Built by Raven's Gate Publishers LLC
