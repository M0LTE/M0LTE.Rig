#!/usr/bin/env bash
# check-ascii-output.sh - two tripwires against non-ASCII output and non-ASCII dashes.
#
#   scripts/check-ascii-output.sh
#
# Anything that reaches a terminal comes back as <E2><80><94> in `journalctl`, whose pager runs
# under a C locale on a stock Debian box - so an em dash or a U+2192 arrow in a message is noise
# in the one place someone reads it. These are libraries rather than daemons, so the surface that
# matters here is exception messages: they are what a consuming app logs.
#
# Check 1 - operator-facing strings, in src/ only (comments and docs are free to use whatever
# notation they like):
#   - every double-quoted string literal on a line that throws or builds an exception
#   - Console output, for anything that grows a CLI later
#
# Check 2 - em dash (U+2014) or en dash (U+2013) anywhere in a git-tracked file. Nobody on this
# project ever means to type one; every one that has shown up was an agent's habit, not a
# deliberate choice, so this is a whole-repo tripwire rather than a src/-only one. LICENSE is a
# verbatim third-party text and is exempt; everything else - code, comments, docs, CHANGELOG -
# should use a hyphen, comma or semicolon instead.
#
# This is a cheap line-based tripwire, not a lexer. If it ever needs to be exact, parse with
# Roslyn rather than widening the grep until it false-positives.
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$root"

patterns='throw new |Exception\(|Console\.(Write|WriteLine|Error\.|Out\.)'

hits="$(grep -rnE --include='*.cs' "$patterns" src/ | grep -P '"[^"]*[^\x00-\x7F][^"]*"' || true)"

if [ -n "$hits" ]; then
    echo "::error::non-ASCII characters in operator-facing output (they render as <E2><80><94> in journalctl)"
    echo "$hits"
    echo
    echo "Use plain ASCII: '->' not an arrow, '-' or ';' not an em dash. Comments may keep theirs."
    exit 1
fi

echo "ok: every exception message and Console string in src/ is plain ASCII"

dash_hits="$(git ls-files -z | grep -zv '^LICENSE$' | xargs -0 grep -n $'\xE2\x80\x94\|\xE2\x80\x93' -- 2>/dev/null || true)"

if [ -n "$dash_hits" ]; then
    echo "::error::em dash (U+2014) or en dash (U+2013) found in a tracked file (LICENSE excepted)"
    echo "$dash_hits"
    echo
    echo "Use a hyphen, comma or semicolon instead."
    exit 1
fi

echo "ok: no em dash or en dash in any tracked file (LICENSE excepted)"
