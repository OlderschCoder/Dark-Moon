#!/usr/bin/env bash
set -u
# ⚠️ PAS de set -e global (contrôlé manuellement)

log() {
  printf '[%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*"
}

fatal() {
  log "FATAL: $*"
  exit 1
}

#######################################
# Paths
#######################################
OPENCODE_HOME="${OPENCODE_HOME:-${HOME:-/root}}"
XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$OPENCODE_HOME/.config}"
XDG_DATA_HOME="${XDG_DATA_HOME:-$OPENCODE_HOME/.local/share}"

AGENTS_DIR="${OPENCODE_AGENTS_DIR:-$OPENCODE_HOME/.opencode/agents}"
DEFAULT_AGENTS="${DEFAULT_AGENTS:-/opt/darkmoon/default-agents}"
DEFAULT_WORKFLOWS="${DEFAULT_WORKFLOWS:-/opt/darkmoon/default-workflows}"
WORKFLOWS_DIR="${DARKMOON_WORKFLOWS_DIR:-/opt/darkmoon/mcp/server/src/tools/workflows}"
OPENCODE_CONFIG_FILE="${OPENCODE_CONFIG_FILE:-$XDG_CONFIG_HOME/opencode/opencode.json}"
OPENCODE_AUTH_FILE="${OPENCODE_AUTH_FILE:-$XDG_DATA_HOME/opencode/auth.json}"
APPLY_SCRIPT="${APPLY_SCRIPT:-/opt/darkmoon/conf/apply-settings.sh}"

#######################################
# Sanity checks
#######################################
[ -d "$DEFAULT_AGENTS" ] || fatal "Default agents dir missing: $DEFAULT_AGENTS"

#######################################
# Prepare directories (bind-mount safe)
#######################################
log "Preparing directories"
mkdir -p \
  "$AGENTS_DIR" \
  "$(dirname "$OPENCODE_CONFIG_FILE")" \
  "$(dirname "$OPENCODE_AUTH_FILE")"

#######################################
# Apply OpenCode config (ALWAYS)
#######################################
log "Applying OpenCode configuration (forced)"

log "Runtime environment variables available:"
env | grep -E 'OPENROUTER_|OPENCODE_' \
  | sed -E 's/^([^=]*(KEY|TOKEN|SECRET|PASSWORD)[^=]*)=.*/\1=[REDACTED]/' || true

[ -x "$APPLY_SCRIPT" ] || fatal "Apply script not executable: $APPLY_SCRIPT"

if ! "$APPLY_SCRIPT"; then
  fatal "apply-settings failed"
fi

#######################################
# Seed agents (VOLUME-SAFE)
#######################################
log "Checking agents directory"

mkdir -p "$AGENTS_DIR"

if [ -z "$(ls -A "$AGENTS_DIR" 2>/dev/null)" ]; then
  log "Agents dir empty → seeding from image"

  if ! cp -a "$DEFAULT_AGENTS/." "$AGENTS_DIR/"; then
    fatal "Failed to seed agents"
  fi

  log "Agents seeded successfully"
else
  log "Agents dir already populated → skip"
fi

#######################################
# Seed workflows (VOLUME-SAFE)
#######################################
log "Checking workflows directory"

mkdir -p "$WORKFLOWS_DIR"

if [ -z "$(ls -A "$WORKFLOWS_DIR" 2>/dev/null)" ]; then
  log "Workflows dir empty → seeding from image"

  if ! cp -a "$DEFAULT_WORKFLOWS/." "$WORKFLOWS_DIR/"; then
    fatal "Failed to seed workflows"
  fi

  log "Workflows seeded successfully"
else
  log "Workflows dir already populated → skip"
fi

#######################################
# Final state summary (debug friendly)
#######################################
log "Final agent directory content:"
ls -la "$AGENTS_DIR"


#######################################
# OpenCode Markdown export watcher
#######################################
#######################################
# Real-time Markdown watcher (inotify)
#######################################

SESSIONS_DIR="${OPENCODE_SESSIONS_DIR:-$XDG_DATA_HOME/opencode/sessions}"
WATCH_DIR="${OPENCODE_MARKDOWN_WATCH_DIR:-$OPENCODE_HOME}"

log "Preparing OpenCode sessions directory"
mkdir -p "$SESSIONS_DIR" "$WATCH_DIR"

log "Starting real-time Markdown watcher (inotify on $WATCH_DIR)"

inotifywait -m "$WATCH_DIR" \
  -e create -e moved_to -e close_write \
  --format '%w%f' |
while read -r path; do
  file="$(basename "$path")"

  case "$file" in
    *.md) ;;
    *) continue ;;
  esac

  case "$path" in
    "$WATCH_DIR"/*.md) ;;
    *) continue ;;
  esac

  src="$path"
  dst="$SESSIONS_DIR/$file"

  [ -f "$src" ] || continue

  if [ -f "$dst" ]; then
    ts=$(date '+%Y%m%d-%H%M%S')
    dst="$SESSIONS_DIR/${file%.md}-$ts.md"
  fi

  log "Markdown detected → moving $src → $dst"
  mv -f "$src" "$dst"
done &

#######################################
# Start main process
#######################################
log "Starting main process: $*"
exec "$@"