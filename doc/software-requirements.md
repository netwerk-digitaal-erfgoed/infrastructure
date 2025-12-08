# NDE Software Requirements

## Introduction

This document specifies minimal technical requirements for software services to be able to run in the NDE infrastructure.
These requirements apply to web applications as well as APIs and background services.
The requirements are an application of the [CLARIAH Software and Service Requirements](https://github.com/CLARIAH/clariah-plus/blob/main/requirements/software-requirements.md)
to the NDE context.

## Requirements

### 1. The software’s source code *MUST* be stored in a public version control system.

This defaults to [NDE’s GitHub organization](https://github.com/netwerk-digitaal-erfgoed/).

See [CLARIAH #1](https://github.com/CLARIAH/clariah-plus/blob/main/requirements/software-requirements.md#1-the-softwares-source-code-must-be-stored-in-a-public-version-control-system-vcs)

### 2. A README file *MUST* be provided in the root directory.

See [CLARIAH #2](https://github.com/CLARIAH/clariah-plus/blob/main/requirements/software-requirements.md#2-a-readme-file-must-be-provided-in-the-root-directory-of-the-vcs).
 
### 3. The software *MUST* have a public issue tracker. 

This defaults to the repository’s issue tracker on GitHub.

See [CLARIAH #7](https://github.com/CLARIAH/clariah-plus/blob/main/requirements/software-requirements.md#7-the-software-should-have-a-public-support-channel).

### 4. The software *MUST* be packaged as a container.

The software service MUST be packaged as an [OCI](https://opencontainers.org) container (e.g. Docker containers) for portability.

See [CLARIAH #15](https://github.com/CLARIAH/clariah-plus/blob/main/requirements/software-requirements.md#15-services-must-be-packaged-as-containers).

### 5. The container must be tagged with an incremental version number.

The end of tech must either be a [semantic version increment](https://semver.org) or a simple timestamp-based increment
(`git show -s --format=%cd-%h --date=format:%Y%m%d%H%M%S`).

See [CLARIAH #4](https://github.com/CLARIAH/clariah-plus/blob/main/requirements/software-requirements.md#4-the-software-must-be-released-periodically-with-clear-version-numbers).

### 6. The software *MUST* be configurable through environment variables.

Examples of configuration parameters are credentials, API tokens and database connection information.
These parameters *MUST NOT* be part of the application’s source code.
Instead, the application *MUST* read configuration from environment variables,
the values for which can be provided by the infrastructure.

See [CLARIAH #5](https://github.com/CLARIAH/clariah-plus/blob/main/requirements/software-requirements.md#5-the-software-must-separate-code-from-configuration).

