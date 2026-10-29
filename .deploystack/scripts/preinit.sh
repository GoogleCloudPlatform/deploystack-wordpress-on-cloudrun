#!/usr/bin/env bash
# Copyright 2026 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# Ensure Terraform >= 1.12.2 is installed and first in PATH (fixes #149).
REQUIRED_TF_VERSION="1.12.2"

CURRENT_TF_VERSION=""
if command -v terraform >/dev/null 2>&1; then
  CURRENT_TF_VERSION=$(terraform version -json 2>/dev/null | grep -o '"terraform_version":[[:space:]]*"[^"]*"' | head -n1 | cut -d'"' -f4)
  if [ -z "$CURRENT_TF_VERSION" ]; then
    CURRENT_TF_VERSION=$(terraform version 2>/dev/null | head -n1 | sed -E 's/.*v([0-9]+\.[0-9]+\.[0-9]+).*/\1/')
  fi
fi

version_ge() {
  [ "$(printf '%s\n%s\n' "$2" "$1" | sort -V | head -n1)" = "$2" ]
}

if [ -z "$CURRENT_TF_VERSION" ] || ! version_ge "$CURRENT_TF_VERSION" "$REQUIRED_TF_VERSION"; then
  echo "Terraform ${CURRENT_TF_VERSION:-none} is older than required >= ${REQUIRED_TF_VERSION}. Installing Terraform ${REQUIRED_TF_VERSION}..."
  mkdir -p "$HOME/bin"
  export PATH="$HOME/bin:$PATH"

  if command -v tfswitch >/dev/null 2>&1; then
    tfswitch -b "$HOME/bin/terraform" "$REQUIRED_TF_VERSION"
  else
    TF_TMP_DIR=$(mktemp -d)
    ARCH=$(uname -m)
    case "$ARCH" in
      x86_64|amd64) TF_ARCH="amd64" ;;
      aarch64|arm64) TF_ARCH="arm64" ;;
      *) TF_ARCH="amd64" ;;
    esac
    wget --quiet "https://releases.hashicorp.com/terraform/${REQUIRED_TF_VERSION}/terraform_${REQUIRED_TF_VERSION}_linux_${TF_ARCH}.zip" -O "${TF_TMP_DIR}/terraform.zip" \
      && unzip -q -o "${TF_TMP_DIR}/terraform.zip" -d "$HOME/bin" \
      && chmod +x "$HOME/bin/terraform"
    rm -rf "${TF_TMP_DIR}"
  fi

  if [ -w /usr/bin/terraform ]; then
    cp -f "$HOME/bin/terraform" /usr/bin/terraform
  elif command -v sudo >/dev/null 2>&1 && sudo -n true 2>/dev/null; then
    sudo -n cp -f "$HOME/bin/terraform" /usr/bin/terraform || true
  fi
fi
