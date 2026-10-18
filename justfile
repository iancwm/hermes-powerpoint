set shell := ["bash", "-euo", "pipefail", "-c"]

default:
    @just --list

sync:
    uv sync

test *args:
    uv run pytest {{args}}

step n:
    #!/usr/bin/env bash
    set -euo pipefail
    shopt -s nullglob
    files=(provision/0"{{n}}"-*.sh)
    if [ "${#files[@]}" -ne 1 ]; then
        echo "step {{n}}: expected exactly one script matching provision/0{{n}}-*.sh, found ${#files[@]}" >&2
        exit 1
    fi
    bash "${files[0]}"

preflight:
    @just step 0

install:
    @just step 1

pptx:
    @just step 2

gates:
    @just step 3

skills:
    @just step 4

smoke:
    @just step 5

layout:
    @just step 6

report:
    @just step 7

from n="0":
    #!/usr/bin/env bash
    set -euo pipefail
    for i in $(seq "{{n}}" 7); do
        just step "$i"
    done

all:
    @just from 0
