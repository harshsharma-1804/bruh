# Bruh

> Install it. Switch it. Forget the syntax.

Bruh is a runtime and tool environment manager. One command installs, activates, and manages Node, Java, Python, Go, Rust, Yarn, and pnpm — across any version, with no tool-specific syntax to remember.

```bash
bruh node 22
bruh java 21 temurin
bruh python 3.12
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

Five tools. Five syntaxes. Five config files. Bruh replaces all of that with a single unified interface. Same command, every tool, every runtime.

**No hidden managers.** Bruh talks directly to Homebrew and rustup. It does not wrap nvm, asdf, sdkman, or any other version manager.

**Provenance tracking.** Bruh remembers what it installed vs what was already on your machine. `bruh goodbye` only removes what Bruh put there — nothing else.

**JDK provider choice.** For Java, Bruh lets you pick your distribution — OpenJDK, Temurin, Corretto, Zulu, GraalVM, or Oracle — and tracks which provider each version came from.

**Search before you install.** `bruh search java` shows every available JDK distribution and provider from Homebrew before you install anything.

---

## Requirements

- macOS (Apple Silicon or Intel) — Linux support coming in Phase 3
- Homebrew — installed automatically if not present
- `jq` — installed automatically via Homebrew

---

## Install

**One-line install:**

```bash
curl -fsSL https://raw.githubusercontent.com/BRUH_REPO_PLACEHOLDER/main/install.sh | bash
```

**From a local clone:**

```bash
git clone https://github.com/BRUH_REPO_PLACEHOLDER
cd bruh
bash install.sh
```

The installer checks for Homebrew, installs it if missing, installs `jq`, scaffolds `~/tools/bruh/`, and adds the source line to your shell config automatically.

---

## Activate

After install, activate Bruh in your current terminal without opening a new one:

```bash
source ~/tools/bruh/env/bruh.env
```

Every new terminal after that loads Bruh automatically.

---

## Quick Start

```bash
bruh search java          # see all available JDK distributions
bruh java 21 temurin      # install Java 21 from Temurin
bruh node 22              # install and activate Node 22
bruh python 3.12          # install and activate Python 3.12
bruh runtimes             # see status of all tools
```

---

## Full Command Reference

See **[COMMANDS.md](./COMMANDS.md)** for every command Bruh supports.

---

## Uninstall

```bash
bruh goodbye
```

Removes everything Bruh installed and every trace of itself. Pre-existing runtimes you had before Bruh are not touched.

---

## License

MIT
