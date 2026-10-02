#!/usr/bin/env bash
# Ocho Kart Recomp - development environment setup.
set -euo pipefail

echo ">[setup_dev_env.sh] Installing git hooks"
git config core.hooksPath scripts/hooks
chmod +x scripts/hooks/pre-commit 2>/dev/null || true

echo ">[setup_dev_env.sh] Dependencies"
echo "   git, cmake, C++ compiler (Clang), Python 3"
echo "   Phase 4 adds DirectXShaderCompiler (DXC) for HLSL -> DXIL/SPIR-V"
echo "   Then: git submodule update --init --recursive"
