#!/usr/bin/env bash
set -euo pipefail

OPENCODE_HOME="${OPENCODE_HOME:-${HOME:-/root}}"
XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$OPENCODE_HOME/.config}"
XDG_DATA_HOME="${XDG_DATA_HOME:-$OPENCODE_HOME/.local/share}"
AGENTS_DIR="${OPENCODE_AGENTS_DIR:-$OPENCODE_HOME/.opencode/agents}"

OPENCODE_CONFIG_DIR="${OPENCODE_CONFIG_DIR:-$XDG_CONFIG_HOME/opencode}"
OPENCODE_CONFIG_FILE="$OPENCODE_CONFIG_DIR/opencode.json"

OPENCODE_AUTH_DIR="${OPENCODE_AUTH_DIR:-$XDG_DATA_HOME/opencode}"
OPENCODE_AUTH_FILE="$OPENCODE_AUTH_DIR/auth.json"

fail() { echo "❌ $*" >&2; exit 1; }
log()  { echo "[INIT] $*" >&2; }

#######################################
# Environment (injected by runtime via .opencode.env)
#######################################

# Cloud provider vars
OPENROUTER_PROVIDER="${OPENROUTER_PROVIDER:-}"
OPENROUTER_API_KEY="${OPENROUTER_API_KEY:-}"
OPENCODE_MODEL="${OPENCODE_MODEL:-}"

if [ -z "$OPENROUTER_API_KEY" ] && [ -r /run/secrets/openrouter_api_key ]; then
  OPENROUTER_API_KEY="$(tr -d '\r\n' < /run/secrets/openrouter_api_key)"
fi

# Local provider vars
OPENCODE_LOCAL_MODE="${OPENCODE_LOCAL_MODE:-false}"
OPENCODE_LOCAL_PROVIDER_ID="${OPENCODE_LOCAL_PROVIDER_ID:-}"
OPENCODE_LOCAL_PROVIDER_NAME="${OPENCODE_LOCAL_PROVIDER_NAME:-Local model}"
OPENCODE_LOCAL_BASE_URL="${OPENCODE_LOCAL_BASE_URL:-}"
OPENCODE_LOCAL_MODEL="${OPENCODE_LOCAL_MODEL:-}"

#######################################
# Decide model strategy
# Priority: local > cloud > fallback
#######################################
USE_LOCAL=false
USE_OPENROUTER=false

if [ "${OPENCODE_LOCAL_MODE}" = "true" ] && \
   [ -n "${OPENCODE_LOCAL_PROVIDER_ID:-}" ] && \
   [ -n "${OPENCODE_LOCAL_BASE_URL:-}" ] && \
   [ -n "${OPENCODE_LOCAL_MODEL:-}" ]; then
  USE_LOCAL=true
elif [ -n "${OPENROUTER_PROVIDER:-}" ] && \
     [ -n "${OPENROUTER_API_KEY:-}" ] && \
     [ -n "${OPENCODE_MODEL:-}" ]; then
  USE_OPENROUTER=true
fi

if [ "$USE_LOCAL" = true ]; then
  # Local provider: model string is just the model name (no provider/ prefix)
  FINAL_MODEL="${OPENCODE_LOCAL_PROVIDER_ID}/${OPENCODE_LOCAL_MODEL}"
  log "Using local provider: ${OPENCODE_LOCAL_PROVIDER_NAME} → model: ${FINAL_MODEL}"
  log "Base URL: ${OPENCODE_LOCAL_BASE_URL}"
elif [ "$USE_OPENROUTER" = true ]; then
  FINAL_MODEL="$OPENROUTER_PROVIDER/$OPENCODE_MODEL"
  log "Using cloud provider: $FINAL_MODEL"
else
  FINAL_MODEL="opencode/big-pickle"
  log "No provider configured → fallback to $FINAL_MODEL"
fi

#######################################
# Create directories
#######################################
mkdir -p "$OPENCODE_CONFIG_DIR" "$OPENCODE_AUTH_DIR"

#######################################
# Write opencode.json (ALWAYS)
#######################################

# Build optional provider block for local mode
LOCAL_PROVIDER_BLOCK=""
if [ "$USE_LOCAL" = true ]; then
  LOCAL_PROVIDER_BLOCK=$(cat <<PROVEOF
,

  "provider": {
    "${OPENCODE_LOCAL_PROVIDER_ID}": {
      "npm": "@ai-sdk/openai-compatible",
      "name": "${OPENCODE_LOCAL_PROVIDER_NAME}",
      "options": {
        "baseURL": "${OPENCODE_LOCAL_BASE_URL}"
      },
      "models": {
        "${OPENCODE_LOCAL_MODEL}": {
          "name": "${OPENCODE_LOCAL_MODEL}"
        }
      }
    }
  }
PROVEOF
)
fi

cat > "$OPENCODE_CONFIG_FILE" <<EOF
{
  "\$schema": "https://opencode.ai/config.json"${LOCAL_PROVIDER_BLOCK},

  "mcp": {
    "darkmoon": {
      "type": "local",
      "command": ["/usr/local/bin/darkmoon-mcp"],
      "timeout": 36000000,
      "enabled": true
    }
  },

  "permission": { "*": "allow" },

  "agent": {
    "pentest": {
      "model": "$FINAL_MODEL",
      "mcp": ["darkmoon"],
      "primary": true,
      "prompt_file": "$AGENTS_DIR/pentest.md"
    },

    "active-directory": {
      "model": "$FINAL_MODEL",
      "mcp": ["darkmoon"],
      "secondary": true,
      "prompt_file": "$AGENTS_DIR/ad.md"
    },

    "aspnet": {
      "model": "$FINAL_MODEL",
      "mcp": ["darkmoon"],
      "secondary": true,
      "prompt_file": "$AGENTS_DIR/aspnet.md"
    },

    "python-flask": {
      "model": "$FINAL_MODEL",
      "mcp": ["darkmoon"],
      "secondary": true,
      "prompt_file": "$AGENTS_DIR/flask.md"
    },

    "graphql": {
      "model": "$FINAL_MODEL",
      "mcp": ["darkmoon"],
      "secondary": true,
      "prompt_file": "$AGENTS_DIR/graphql.md"
    },

    "headless-browser": {
      "model": "$FINAL_MODEL",
      "mcp": ["darkmoon"],
      "secondary": true,
      "prompt_file": "$AGENTS_DIR/headless-browser.md"
    },

    "kubernetes": {
      "model": "$FINAL_MODEL",
      "mcp": ["darkmoon"],
      "secondary": true,
      "prompt_file": "$AGENTS_DIR/kubernetes.md"
    },

    "nest": {
      "model": "$FINAL_MODEL",
      "mcp": ["darkmoon"],
      "secondary": true,
      "prompt_file": "$AGENTS_DIR/nest.md"
    },

    "php": {
      "model": "$FINAL_MODEL",
      "mcp": ["darkmoon"],
      "secondary": true,
      "prompt_file": "$AGENTS_DIR/php.md"
    },

    "ruby-on-rails": {
      "model": "$FINAL_MODEL",
      "mcp": ["darkmoon"],
      "secondary": true,
      "prompt_file": "$AGENTS_DIR/ruby.md"
    },

    "springboot": {
      "model": "$FINAL_MODEL",
      "mcp": ["darkmoon"],
      "secondary": true,
      "prompt_file": "$AGENTS_DIR/springboot.md"
    },

    "nodejs": {
      "model": "$FINAL_MODEL",
      "mcp": ["darkmoon"],
      "secondary": true,
      "prompt_file": "$AGENTS_DIR/nodejs-express-angular.md"
    },

    "wordpress": {
      "model": "$FINAL_MODEL",
      "mcp": ["darkmoon"],
      "secondary": true,
      "prompt_file": "$AGENTS_DIR/wordpress.md"
    },

    "prestashop": {
      "model": "$FINAL_MODEL",
      "mcp": ["darkmoon"],
      "secondary": true,
      "prompt_file": "$AGENTS_DIR/prestashop.md"
    },

    "moodle": {
      "model": "$FINAL_MODEL",
      "mcp": ["darkmoon"],
      "secondary": true,
      "prompt_file": "$AGENTS_DIR/moodle.md"
    },

    "magento": {
      "model": "$FINAL_MODEL",
      "mcp": ["darkmoon"],
      "secondary": true,
      "prompt_file": "$AGENTS_DIR/magento.md"
    },

    "joomla": {
      "model": "$FINAL_MODEL",
      "mcp": ["darkmoon"],
      "secondary": true,
      "prompt_file": "$AGENTS_DIR/joomla.md"
    },

    "drupal": {
      "model": "$FINAL_MODEL",
      "mcp": ["darkmoon"],
      "secondary": true,
      "prompt_file": "$AGENTS_DIR/drupal.md"
    }
  }
}
EOF

echo "✅ OpenCode config written to $OPENCODE_CONFIG_FILE"

#######################################
# Write auth.json ONLY for cloud providers
#######################################
if [ "$USE_OPENROUTER" = true ]; then
  cat > "$OPENCODE_AUTH_FILE" <<EOF
{
  "$OPENROUTER_PROVIDER": {
    "type": "api",
    "key": "$OPENROUTER_API_KEY"
  }
}
EOF
  echo "✅ OpenCode auth written to $OPENCODE_AUTH_FILE"
elif [ "$USE_LOCAL" = true ]; then
  rm -f "$OPENCODE_AUTH_FILE"
  log "Local provider — no auth.json needed"
else
  rm -f "$OPENCODE_AUTH_FILE"
  log "No auth.json written (fallback model does not require API key)"
fi

#######################################
# Optional warmup (SAFE, NON BLOCKING)
#######################################

#######################################
# Optional opencode TUI bootstrap (TEST — NO KILL)
#######################################

log "Optional opencode TUI bootstrap (test mode, no kill)"

if command -v /usr/local/bin/opencode >/dev/null 2>&1; then
  (
    # Lancer opencode dans un vrai pseudo-TTY
    script -q -c "/usr/local/bin/opencode --model \"$FINAL_MODEL\"" /dev/null &
    OPENCODE_PID=$!

    log "opencode TUI started in background (pid=$OPENCODE_PID)"
    log "NOT killing it — test mode"
  ) &
fi

log "Warmup finished (script continues)"
