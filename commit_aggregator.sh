
#!/bin/bash
set -euo pipefail
function usage() {
  readarray -t formats < <(
    declare -F \
      | awk '{print $3}' \
      | grep '^output_' \
      | sed 's/^output_//'
  )
  local format_list
  format_list="$(printf ", %s" "${formats[@]}")"
  format_list="${format_list:2}"
  cat << EOF
Usage:
  $(basename "$0") [options] <topic>
Get the list of commits and their status for a work package.
OPTIONS
  -h, --help                  Prints this message and exits.
  -f, --format FORMAT         Output format ($format_list).
                              Default: pretty.
  -o, --output FILE           File to output to. Default: /dev/stdout.
EOF
}
function query_gerrit() {
  local server=$1
  local query=$2
  ssh "$server" -- gerrit query --format JSON -- "$query" | sed '$d'
}
function get_commits() {
  local query=$1
  for server in "${GERRIT_SERVERS[@]}"; do
    query_gerrit "$server" "$query"
  done
}
function output_pretty() {
  function format_line() {
    jq -r '.url + " : " + .subject'
  }
  readarray -t internal_review < <(echo "${INTERNAL_REVIEW[@]}" | format_line)
  readarray -t da_review < <(echo "${DA_REVIEW[@]}" | format_line)
  readarray -t merged < <(echo "${MERGED[@]}" | format_line)
  cat << EOF
Pending internal review
=======================
${internal_review[*]}
Ready for DA review
===================
${da_review[*]}
Merged
======
${merged[*]}
EOF
}
function output_csv() {
  function format_line() {
    local status=$1
    jq -r '"\"[" + .subject + "](" + .url + ")\",'"$status"'"'
  }
  readarray -t internal_review < <(echo "${INTERNAL_REVIEW[@]}" | format_line "Pending internal review")
  readarray -t da_review < <(echo "${DA_REVIEW[@]}" | format_line "Ready for DA review")
  readarray -t merged < <(echo "${MERGED[@]}" | format_line "Merged")
  cat << EOF
Commit,Status
${internal_review[*]}
${da_review[*]}
${merged[*]}
EOF
}
function output_markdown() {
  function format_line() {
    jq -r '"- [" + .subject + "](" + .url + ")"'
  }
  readarray -t internal_review < <(echo "${INTERNAL_REVIEW[@]}" | format_line)
  readarray -t da_review < <(echo "${DA_REVIEW[@]}" | format_line)
  readarray -t merged < <(echo "${MERGED[@]}" | format_line)
  cat << EOF
# Pending internal review
${internal_review[*]}
# Ready for DA review
${da_review[*]}
# Merged
${merged[*]}
EOF
}
function output_json() {
  OUTPUT=
  OUTPUT="$OUTPUT$(echo "${INTERNAL_REVIEW[@]}" | jq -n '{ "internal_review": [inputs] }')"
  OUTPUT="$OUTPUT$(echo "${DA_REVIEW[@]}" | jq -n '{ "da_review": [inputs] }')"
  OUTPUT="$OUTPUT$(echo "${MERGED[@]}" | jq -n '{ "merged": [inputs] }')"
  echo "$OUTPUT" | jq -s '.[0] * .[1] * .[2]'
}
GERRIT_SERVERS=(
  ssh://gerrit-beta.gic.ericsson.se:29418
  ssh://gerrit-gamma.gic.ericsson.se:29418
)
TOPIC=
OUTPUT_FILE=/dev/stdout
FORMAT=pretty
while [[ $# -gt 0 ]]; do
  case "$1" in
    -h | --help)
      usage
      exit
      ;;
    -f | --format)
      FORMAT="$2"
      shift
      ;;
    -o | --output)
      OUTPUT_FILE="$2"
      shift
      ;;
    -*)
      echo "Unknown option: $1" >&2
      exit 1
      ;;
    *)
      TOPIC=$1
      ;;
  esac
  shift
done
if [ -z "$TOPIC" ]; then
  echo "The topic is a required positional argument." >&2
  exit 1
fi
OUTPUT_FN="output_$FORMAT"
if [ "$(type -t "$OUTPUT_FN")" != function ]; then
  echo "Unknown format: $FORMAT" >&2
  exit 1
fi
INTERNAL_REVIEW="$(get_commits "status:open -is:wip topic:$TOPIC")"
DA_REVIEW="$(get_commits "status:open topic:$TOPIC/da-review-needed")"
MERGED="$(get_commits "status:merged (topic:$TOPIC OR topic:$TOPIC/da-review-needed)")"
IFS=$'\n'
"$OUTPUT_FN" > "$OUTPUT_FILE"
