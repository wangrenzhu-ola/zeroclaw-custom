# Deployment Capability

## ADDED Requirements

### Requirement: Packaging Script
The system MUST provide a script to package the application, configuration, and runtime artifacts into a portable archive.

#### Scenario: Create Comprehensive Package
Given the source code is cloned
And the rust toolchain is available
And local skills are defined in `.claude/skills` and `../.trae/skills`
When I run `./package.sh`
Then a `dist/` directory is created
And a `zeroclaw-custom.tar.gz` file exists in `dist/`
And the archive contains:
  - `bin/zeroclaw` (compiled binary)
  - `config/config.toml` (default config)
  - `skills/` (containing both repo skills and local trading skills)
  - `python/` (python tools and dependencies)
  - `setup.sh` (remote installation script)

### Requirement: Deployment Script
The system MUST provide a script to deploy the package to a remote server, ensuring environment consistency.

#### Scenario: Deploy and Sync Environment
Given a valid `zeroclaw-custom.tar.gz` package
And valid SSH credentials for the remote server
When I run `./deploy.sh <remote_host>`
Then the package is transferred to the remote server
And the package is extracted to `~/zeroclaw`
And `setup.sh` is executed on the remote server to:
  - Install system dependencies (git, python3, etc.)
  - Install the `zeroclaw` binary to PATH
  - Sync configuration to `~/.zeroclaw/config.toml`
  - Sync skills to `~/.zeroclaw/skills`
  - Initialize Python virtual environment for tools
