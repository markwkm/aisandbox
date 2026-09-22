#!/bin/sh
# npm-distributed agents: Claude Code, Codex CLI, opencode,
# openclaw, and Mario Zechner's pi (now published under the
# @earendil-works scope; the old @mariozechner packages are
# deprecated).
#
# --allow-scripts approves the install scripts these packages
# and their dependencies run: npm 11 only warns about scripts
# not covered by allowScripts, but npm 12 will refuse to run
# them, and "npm approve-scripts" cannot cover global installs.
# The flag takes one comma-separated argument, assembled here
# so no line runs long.  @openai/codex and the platform-binary
# packages it pulls in declare no install scripts, so no entry
# covers them.
set -eu

scripts="@anthropic-ai/claude-code,@google/genai,opencode-ai"
scripts="${scripts},openclaw,protobufjs,tree-sitter-bash"

npm install -g \
    --allow-scripts="${scripts}" \
    @anthropic-ai/claude-code \
    @earendil-works/pi-coding-agent \
    @openai/codex \
    opencode-ai \
    openclaw
