# BRUH: Zero-Dependency Version Management Plan

## 1. Objective
Transition BRUH to a standalone binary manager that downloads official release artifacts directly. This ensures total isolation, support for any version, and a 100% clean uninstall (`bruh goodbye`).

## 2. Core Architecture Change
**New Flow**: `bruh` $\to$ `curl/wget` (official binary) $\to$ `$BRUH_HOME/runtimes/[tool]/[version]` $\to$ Symlink.

## 3. Implementation Phases

### Phase 1: Core Infrastructure (`lib/core.sh`)
Implement a robust download and extraction utility to be used by all providers.
- **`bruh_download_extract`**: A function that takes a URL and a target directory, downloads the archive (`.tar.gz`, `.zip`, `.tgz`), and extracts it.
- **Architecture Detection**: Logic to detect `darwin-arm64`, `darwin-x64`, `linux-x64`, etc., to fetch the correct binary.

### Phase 2: Provider Migration (The "Silo" Model)
Each provider in `providers/*.sh` will be rewritten to use the new infrastructure.

#### A. Node.js (Proof of Concept)
- Source: `https://nodejs.org/dist/v[version]/node-v[version]-darwin-arm64.tar.gz`
- Strategy: Download $\to$ Extract $\to$ Link to `v[version]`.

#### B. Java (JDK)
- Source: Adoptium (Eclipse Temurin) API.
- Strategy: Fetch the latest release JSON $\to$ Get download URL for specific version/OS $\to$ Extract.

#### C. Python
- Source: Python.org binaries or `python-build` logic.
- Strategy: Use pre-compiled binaries for macOS/Linux where possible.

#### D. Go/Rust/Maven
- Source: Official release pages.
- Strategy: Direct binary download $\to$ Extract to versioned folder.

### Phase 3: Registry & Symlink Refinement
- **Verification**: The registry will no longer just track "installed" flags, but will verify the existence of the binary within the `$BRUH_HOME` directory.
- **Simplified Removal**: `bruh remove` will now simply be `rm -rf $NODE_RUNTIME_HOME/v$version`.

### Phase 4: Total Cleanup (`bruh goodbye`)
- The uninstall process will be reduced to:
  1. Remove shell integration from `.zshrc` / `.bashrc`.
  2. `rm -rf "$BRUH_HOME"`.
- No `sudo` anywhere — everything lives inside `$BRUH_HOME`.

## 4. Expected Outcome
- **Zero Dependencies**: No package manager required.
- **Absolute Isolation**: Tools are contained entirely within the BRUH directory.
- **Instant Switching**: Symlinks are updated locally without affecting system-wide paths.
- **Clean State**: System remains pristine after `bruh goodbye`.
