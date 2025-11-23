#!/bin/sh
printf '\033c\033]0;%s\a' Nine Lives
base_path="$(dirname "$(realpath "$0")")"
"$base_path/nine_lives__0_1_0.dmg.x86_64" "$@"
