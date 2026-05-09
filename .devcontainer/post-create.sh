#!/usr/bin/env bash
set -euo pipefail

bundle install

curl -fsSL https://pi.dev/install.sh | sh