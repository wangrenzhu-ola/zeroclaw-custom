# ZeroClaw Custom Deployment Pipeline

## Context
We need to maintain a custom variant of ZeroClaw locally and deploy it to a US server.

## Goals
1.  **Local Maintenance**: Establish a workflow for modifying ZeroClaw locally.
2.  **One-click Packaging**: Create a script/mechanism to package the code and environment.
3.  **Deployment**: Deploy the package to the US server (which is clean).

## Implementation Plan

### 1. Local Setup
- Clone the repository.
- Verify local build/run.

### 2. Customization (Placeholder)
- This step will be defined as we identify specific customizations needed. For now, we assume the current state is the starting point.

### 3. Packaging
- Create a `package.sh` script.
- The package should include:
    - Source code (or built binaries).
    - Runtime dependencies (python env, system libs if portable).
    - Configuration files.
- Output: A compressed archive (e.g., `zeroclaw-custom.tar.gz`).

### 4. Deployment
- Create a `deploy.sh` script.
- Transfer the package to the US server (using `scp` via tunnel if needed, or direct if possible).
- Unpack and setup on the remote server.
    - Install system dependencies (if not packaged).
    - Setup Python environment.
    - Setup Rust environment (if building remotely) or run binaries.
    - Start the service.

## Verification Plan
1.  **Local Build**: `cargo build --release` succeeds.
2.  **Packaging**: `package.sh` creates a valid tarball containing necessary files.
3.  **Deployment**: `deploy.sh` successfully uploads and starts the service on US server.
4.  **Remote Health**: Remote service responds to health check (e.g., `zeroclaw status`).
