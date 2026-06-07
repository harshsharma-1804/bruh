# Bruh — Command Reference

Every command Bruh supports, grouped by category.

---

## Tools

| Name | Aliases |
|---|---|
| `node` | `nodejs`, `node.js` |
| `java` | `jdk`, `openjdk` |
| `python` | `python3`, `py` |
| `go` | `golang` |
| `rust` | `cargo` |
| `yarn` | — |
| `pnpm` | — |
| `maven` | `mvn` |

---

## Search

Discover what is available to install before installing anything.

```bash
bruh search                        # show tool picker — prompts you to pick a tool
bruh search node                   # list available Node versions from Homebrew
bruh search java                   # list all JDK distributions and providers
bruh search java 21                # filter to Java 21 only — shows all providers for that version
bruh search python                 # list available Python versions from Homebrew
bruh search go                     # list available Go versions from Homebrew
bruh search rust                   # list available Rust channels (stable, beta, nightly)
bruh search yarn                   # list available Yarn versions from npm registry
bruh search pnpm                   # list available pnpm versions from npm registry
bruh search maven                  # list available Maven versions from Homebrew
```

Installed versions are marked in the search output so you can see what you already have.

---

## Lookup

Show what you have installed, with active and default markers.

```bash
bruh lookup                        # show tool picker — prompts you to pick a tool
bruh lookup node                   # list installed Node versions (active + default marked)
bruh lookup java                   # list installed Java versions with provider column
bruh lookup python                 # list installed Python versions
bruh lookup go                     # list installed Go versions
bruh lookup rust                   # list installed Rust toolchains
bruh lookup yarn                   # list installed Yarn versions with exact semver
bruh lookup pnpm                   # list installed pnpm versions with exact semver
bruh lookup maven                  # list installed Maven versions
```

Each `lookup` output shows:
- `▸` — currently active version
- `(default)` — version loaded in new terminals
- Current version, default version, and binary path at the bottom

---

## Install / Activate

```bash
bruh <tool> <version>              # install if not present, then activate
bruh install <tool> <version>      # explicitly install a version
bruh use <tool> <version>          # activate an already-installed version
```

If the version is already installed, `bruh <tool> <version>` activates it. If not, it installs then activates. One command either way.

### Node

```bash
bruh node 22
bruh node 20
bruh node 18
bruh node latest
bruh node stable
bruh node lts
bruh install node 22
bruh use node 20
```

### Java

```bash
bruh java 21                       # install Java 21 with default provider (openjdk)
bruh java 21 temurin               # install Java 21 from Temurin
bruh java 21 corretto              # install Java 21 from Amazon Corretto
bruh java 21 zulu                  # install Java 21 from Azul Zulu
bruh java 21 graalvm               # install Java 21 from GraalVM
bruh java 21 oracle                # install Java 21 from Oracle JDK
bruh java 17
bruh java 17 temurin
bruh java 11
bruh java latest
bruh java stable
bruh java lts
bruh install java 21 temurin
bruh use java 21
```

**JDK Providers:**

| Provider | Formula | Notes |
|---|---|---|
| `openjdk` | `openjdk@<version>` | Oracle open source — default |
| `temurin` | `temurin@<version>` | Eclipse Adoptium — most popular for production |
| `corretto` | `corretto@<version>` | Amazon — AWS optimised, LTS only |
| `zulu` | `zulu@<version>` | Azul — wide platform support |
| `graalvm` | `graalvm-jdk@<version>` | Oracle — native image + polyglot |
| `oracle` | `oracle-jdk@<version>` | Oracle — commercial license |

### Python

```bash
bruh python 3.12
bruh python 3.11
bruh python 3.10
bruh python latest
bruh python stable
bruh install python 3.12
bruh use python 3.11
```

### Go

```bash
bruh go 1.23
bruh go 1.22
bruh go latest
bruh go stable
bruh install go 1.23
bruh use go 1.22
```

### Rust

```bash
bruh rust stable
bruh rust beta
bruh rust nightly
bruh rust 1.78.0                   # specific version
bruh install rust stable
bruh use rust nightly
```

Rustup is installed automatically if not present.

### Yarn

```bash
bruh yarn 4                        # latest 4.x
bruh yarn 4.3.1                    # exact version
bruh yarn 1                        # Yarn Classic v1
bruh yarn latest                   # absolute newest release
bruh yarn stable                   # latest stable
bruh yarn berry                    # latest modern (v2+)
bruh yarn classic                  # latest v1.x
bruh install yarn 4
bruh use yarn 4
```

### pnpm

```bash
bruh pnpm 9                        # latest 9.x
bruh pnpm 9.1.0                    # exact version
bruh pnpm latest
bruh pnpm stable
bruh install pnpm 9
bruh use pnpm 9
```

### Maven

```bash
bruh maven 3.9                     # latest stable (3.9.x)
bruh maven 3.8                     # Maven 3.8 LTS line
bruh maven latest
bruh maven stable
bruh install maven 3.9
bruh use maven 3.9
```

---

## Remove

```bash
bruh remove node 20
bruh remove java 17
bruh remove java 17 temurin        # remove specific provider
bruh remove python 3.11
bruh remove go 1.22
bruh remove rust beta
bruh remove yarn 1
bruh remove pnpm 8
bruh remove maven 3.8
bruh uninstall node 20             # alias for remove
bruh uninstall java 17
bruh uninstall maven 3.8
```

Cannot remove the currently active default version. Change the default first.

---

## Default

Sets the version that loads automatically in every new terminal session.

```bash
bruh default node 22
bruh default java 21
bruh default python 3.12
bruh default go 1.23
bruh default rust stable
bruh default yarn 4
bruh default pnpm 9
bruh default maven 3.9

bruh node default 22               # same as above — tool first form also works
bruh java default 21
bruh python default 3.12
bruh go default 1.23
bruh rust default stable
bruh yarn default 4
bruh pnpm default 9
bruh maven default 3.9
```

---

## Update

```bash
bruh update node                   # update default Node version to latest
bruh update node 22                # update Node 22 specifically
bruh update node all               # update all installed Node versions

bruh update java                   # update default Java version
bruh update java 21
bruh update java all

bruh update python
bruh update python 3.12
bruh update python all

bruh update go
bruh update go 1.23
bruh update go all

bruh update rust                   # runs rustup update for all toolchains
bruh update yarn
bruh update yarn 4
bruh update pnpm
bruh update pnpm 9
bruh update maven
bruh update maven 3.9
bruh update maven all
```

---

## Status & Info

```bash
bruh                               # show status of all tools (current + default)
bruh runtimes                      # full status table — all tools, versions, paths

bruh node                          # show Node current version, default, path
bruh java                          # show Java current version, default, JAVA_HOME, path
bruh python                        # show Python current version, default, path
bruh go                            # show Go current version, default, GOROOT, path
bruh rust                          # show Rust current toolchain, CARGO_HOME, path
bruh yarn                          # show Yarn current version, exact semver, default, path
bruh pnpm                          # show pnpm current version, exact semver, default, path

bruh node where                    # show Node binary path
bruh java where                    # show Java binary path and JAVA_HOME
bruh python where                  # show Python binary path
bruh go where                      # show Go binary path and GOROOT
bruh rust where                    # show rustc and cargo paths
bruh yarn where                    # show Yarn binary path
bruh pnpm where                    # show pnpm binary path
bruh maven                         # show Maven current version, default, MAVEN_HOME, path
bruh maven where                   # show Maven binary path and MAVEN_HOME
```

---

## Per-Project Pinning

Pins a specific package manager version for a single project. Must be run from inside a directory containing a `package.json`.

### Yarn

Writes `.yarnrc.yml` into the current directory and downloads the pinned Yarn release into `.yarn/releases/`. The global Yarn version is not affected.

```bash
bruh yarn set 4.3.1                # pin exact version
bruh yarn set berry                # pin latest modern (v2+)
bruh yarn set stable               # pin latest stable
bruh yarn set classic              # pin v1.x for this project
bruh yarn set latest               # pin absolute newest
```

### pnpm

Writes the `packageManager` field into the project's `package.json`. corepack reads this field to enforce the pinned version.

```bash
bruh pnpm set 9.1.0                # pin exact version
bruh pnpm set latest               # pin latest stable
bruh pnpm set stable               # same as latest
```

---

## Natural Language

Bruh understands plain English. All of these resolve to the same internal commands as their structured equivalents.

```bash
bruh get node 22
bruh get me node 22
bruh i need node 22
bruh i need java 21
bruh setup node 22 for me
bruh install java 21 please
bruh where is node
bruh where is java
bruh what node version
bruh what java version
```

---

## System

```bash
bruh help                          # show full command reference in terminal
bruh runtimes                      # show all tools in a status table
bruh goodbye                       # uninstall Bruh and everything it installed
```

### `bruh goodbye`

A full self-removal with no trace left:

1. Prompts for confirmation
2. Reads registry to build removal plan
3. Uninstalls runtimes Bruh installed via Homebrew (pre-existing ones are left alone)
4. Removes Java JVM symlinks from `/Library/Java/JavaVirtualMachines/` (requires sudo — prompts once)
5. Removes Yarn and pnpm from corepack, Maven from Homebrew
6. Strips the source line from `~/.zshrc` and `~/.bashrc`
7. Unsets all environment variables in the current session
8. Deletes the Bruh install directory

---

## Version Aliases (all tools)

| Alias | Resolves to |
|---|---|
| `latest` | Newest available release |
| `stable` | Latest stable / LTS release |
| `lts` | Same as `stable` |

### Yarn only

| Alias | Resolves to |
|---|---|
| `berry` | Latest modern release (v2+) |
| `classic` | Latest v1.x release |

---

## Action Synonyms

These all work and resolve to the same internal action:

| You type | Resolved to |
|---|---|
| `install`, `get`, `setup`, `add` | install |
| `use`, `switch`, `activate` | activate |
| `remove`, `uninstall`, `delete` | remove |
| `where`, `path`, `locate`, `find` | locate |
| `lookup`, `list`, `ls`, `show`, `installed` | lookup |
| `search`, `find-available`, `available` | search |
| `default` | set default |
| `update`, `upgrade` | update |
