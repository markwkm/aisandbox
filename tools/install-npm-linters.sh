#!/bin/sh
# Linters and formatters distributed via npm: JavaScript, CSS,
# HTML, JSON, and Markdown linters, prettier, and the
# TypeScript compiler (tsc).  JSON linting uses the maintained
# @prantlf/jsonlint fork (same jsonlint command): the original
# jsonlint was last published in 2018 and pulls in the
# abandoned nomnom package.
set -eu

npm install -g \
    @prantlf/jsonlint \
    eslint \
    htmlhint \
    markdownlint-cli \
    prettier \
    stylelint \
    typescript
