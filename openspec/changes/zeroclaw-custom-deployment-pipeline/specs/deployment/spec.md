# Deployment Capability

## ADDED Requirements

### Requirement: Packaging Script
The system MUST provide a script to package the application and its dependencies into a portable archive.

#### Scenario: Create Package
Given the source code is cloned
And the rust toolchain is available
When I run `./package.sh`
Then a `dist/` directory is created
And a `zeroclaw-custom.tar.gz` file exists in `dist/`
And the archive contains the `zeroclaw` binary
And the archive contains configuration templates
And the archive contains python tools.

### Requirement: Deployment Script
The system MUST provide a script to deploy the package to a remote server via SSH.

#### Scenario: Deploy to Remote
Given a valid `zeroclaw-custom.tar.gz` package
And valid SSH credentials for the remote server
When I run `./deploy.sh <remote_host>`
Then the package is transferred to the remote server
And the package is extracted
And system dependencies are installed (if missing)
And the service is started.
