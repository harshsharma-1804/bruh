# Bruh

> Install it. Switch it. Forget the syntax.

Bruh is a runtime and tool environment manager. One command installs, activates, and manages Node, Java, Python, Go, Rust, Yarn, pnpm, and Maven — across any version, with no tool-specific syntax to remember.

```bash
bruh node 22
bruh java 21 temurin
bruh python 3.12
bruh maven 3.9
```

---

## Why Bruh

Every runtime has its own version manager with its own syntax:

| Without Bruh | With Bruh |
|---|---|
| `nvm use 22` | `bruh node 22` |
| `sdk use java 21-open` | `bruh java 21` |
| `pyenv global 3.12.0` | `bruh python 3.12` |
| `gvm use go1.23` | `bruh go 1.23` |
| `rustup default stable` | `bruh rust stable` |
| `mvn` (manually managed) | `bruh maven 3.9` |

Six tools. Six syntaxes. Six config files. Bruh replaces all of that with a single unified interface. Same command, every tool, every runtime.

**No hidden managers.** Bruh downloads official binaries directly from each project (nodejs.org, Adoptium, go.dev, Apache, python-build-standalone) and uses rustup/corepack where they are the official mechanism. It does not wrap nvm, asdf, sdkman, or any other version manager — and it does not need Homebrew.

**Provenance tracking.** Bruh remembers what it installed vs what was already on your machine. `bruh goodbye` only removes what Bruh put there — nothing else.

**JDK provider choice.** For Java, Bruh lets you pick your distribution — Temurin, Corretto, or Oracle — and tracks which provider each version came from. No sudo, no /Library/Java symlinks.

**Search before you install.** `bruh search java` shows every available JDK distribution and provider before you install anything.

---

## Requirements

- macOS (Apple Silicon or Intel) or Linux (x64 / arm64)
- `curl` or `wget`
- `jq` — installed automatically by the installer if missing

---

## Install

```bash
curl -fsSL https://raw.githubusercontent.com/harshsharma-1804/bruh/main/install.sh | bash
```

### From a local clone

```bash
git clone https://github.com/harshsharma-1804/bruh
cd bruh
bash install.sh
```

The installer installs `jq` if missing, scaffolds the install directory, and adds the source line to your shell config automatically. No Homebrew required.

---

## Quick Start

```bash
bruh search java          # see all available JDK distributions
bruh java 21 temurin      # install Java 21 from Temurin
bruh node 22              # install and activate Node 22
bruh python 3.12          # install and activate Python 3.12
bruh go 1.23              # install and activate Go 1.23
bruh rust stable          # install and activate Rust stable
bruh maven 3.9            # install and activate Maven 3.9
bruh runtimes             # see status of all tools
```

---

## How It Works

Bruh is fully self-contained. Every runtime lives inside `$BRUH_HOME` (default `~/.bruh/bruh`):

```
$BRUH_HOME/
├── bin/bruh              # entrypoint
├── lib/                  # core, registry, intent parser
├── providers/            # one script per tool
├── env/                  # shell integration per tool
├── registry/state.json   # what's installed, active, and default
└── runtimes/
    ├── node/v22/         # extracted official binary
    ├── java/v21/         # JDK home — no /Library/Java symlinks, no sudo
    ├── python/v3.12/
    └── .../<current>     # symlink → active version
```

- **Official sources only** — node from nodejs.org, JDKs from Adoptium/Corretto/Oracle, Python from python-build-standalone, Go from go.dev, Maven from Apache, Rust via rustup, Yarn/pnpm via corepack
- **No Homebrew, no sudo** — installs are archive downloads extracted into your `BRUH_HOME`
- **Activation = one symlink** — switching versions instantly re-points `current`; new terminals load your default automatically
- **Clean uninstall** — `bruh goodbye` deletes `$BRUH_HOME` and strips the shell integration. Nothing was ever installed outside it (except Rust toolchains, which live in `~/.rustup` via rustup)

Works on macOS (Apple Silicon + Intel) and Linux (x64 + arm64). Windows support is planned via a native PowerShell module; WSL works today.

---

## Full Command Reference

See **[COMMANDS.md](./COMMANDS.md)** for every command Bruh supports.

---

## Uninstall

```bash
bruh goodbye
```

Removes everything Bruh installed and every trace of itself — no sudo prompts, no Homebrew uninstall loops. Pre-existing runtimes you had before Bruh are not touched.

---

## License

MIT
