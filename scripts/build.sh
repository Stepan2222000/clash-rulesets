#!/usr/bin/env bash
set -euo pipefail

base_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
src_url="https://raw.githubusercontent.com/runetfreedom/russia-blocked-geosite/release/ru-blocked.txt"
src_sha_url="https://api.github.com/repos/runetfreedom/russia-blocked-geosite/commits/release"
out_file="$base_dir/ru-blocked-domain-provider.yaml"
raw_file="$(mktemp)"
trap 'rm -f "$raw_file"' EXIT

curl -fsSL --max-time 120 "$src_url" -o "$raw_file"
src_sha="$(curl -fsSL --max-time 30 "$src_sha_url" | python3 -c 'import json,sys; print(json.load(sys.stdin)["sha"][:12])' 2>/dev/null || echo unknown)"
src_lines="$(wc -l < "$raw_file" | tr -d ' ')"

{
  printf '# Auto-generated from runetfreedom/russia-blocked-geosite\n'
  printf '# Source: %s\n' "$src_url"
  printf '# Source commit: %s (%s lines)\n' "$src_sha" "$src_lines"
  printf '# behavior: domain  format: yaml\n'
  printf '#   "+.example.com" matches example.com and all subdomains (mihomo trie semantics)\n'
  printf '#   "example.com"   exact match only (used for "full:" entries)\n'
  printf 'payload:\n'
  awk -F: '
    /^domain:/ { print "  - '\''+." $2 "'\''" ; next }
    /^full:/   { print "  - '\''"   $2 "'\''" ; next }
  ' "$raw_file" | LC_ALL=C sort -u
} > "$out_file"

out_lines="$(wc -l < "$out_file" | tr -d ' ')"
out_size="$(wc -c < "$out_file" | tr -d ' ')"
printf 'wrote %s (%s payload lines, %s bytes) from source %s\n' "$out_file" "$((out_lines - 7))" "$out_size" "$src_sha"
