# Design: ZeroClaw Custom Deployment

## Architecture
- **Local Dev**: Rust project with local build tools.
- **Packaging**: Shell script (`package.sh`) to bundle binary, config, and assets.
- **Deployment**: Shell script (`deploy.sh`) to transfer and install on remote server.

## Scripts Design

### `package.sh`
- **Input**: Source directory.
- **Process**:
    1.  Clean previous builds (optional).
    2.  Run `cargo build --release`.
    3.  Create a temporary staging directory.
    4.  Copy binary (`target/release/zeroclaw`).
    5.  Copy `config.example.toml` (as template).
    6.  Copy `python/` directory (for python tools).
    7.  Copy `scripts/` (if needed).
    8.  Tar and gzip the staging directory.
- **Output**: `dist/zeroclaw-custom-<version>.tar.gz`

### `deploy.sh`
- **Input**: Package file, Remote Host, Remote User.
- **Process**:
    1.  Check for package file.
    2.  SCP package to remote `/tmp`.
    3.  SSH to remote:
        - Create install directory (e.g., `~/zeroclaw`).
        - Extract package.
        - Install system dependencies (using `apt-get` or `yum` if needed, requires sudo/root).
        - Setup `systemd` service (optional, for persistence).
        - Start the application.

## Remote Environment
- Target: US Server (Ubuntu/Debian assumed).
- Dependencies: `openssl`, `ca-certificates`, `python3`.
