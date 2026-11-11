#!/usr/bin/env bash
# Checks that compliance.yml is filled in and still plausible for the code.
# It only warns, never blocks: it detects signals, not legal facts.
set -u
cd "$(dirname "$0")/.." || exit 1
f=compliance.yml
warned=0
warn() {
  warned=1
  if [ -n "${GITHUB_ACTIONS:-}" ]; then echo "::warning file=$f::$1"; else echo "[warn] $1"; fi
}
[ -f "$f" ] || { warn "compliance.yml is missing"; exit 0; }

# Value of "  key:" inside a top-level "section:" block.
get() {
  awk -v s="$1" -v k="$2" '
    /^[^ #]/ { insec = ($0 ~ "^" s ":") }
    insec && $0 ~ "^  " k ":" { sub("^  " k ":[ ]*", ""); sub(/[ ]*#.*/, ""); print; exit }' "$f"
}

todo=$(grep -cE ':[[:space:]]*TODO' "$f")
[ "$todo" -gt 0 ] && warn "$todo field(s) still TODO in $f"

reviewed=$(awk '/^reviewed:/ { print $2 }' "$f")
if [[ "$reviewed" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
  if then_s=$(date -d "$reviewed" +%s 2>/dev/null); then
    age=$(( ($(date +%s) - then_s) / 86400 ))
    [ "$age" -gt 180 ] && warn "$f last reviewed $age days ago: confirm it still matches the project"
  fi
fi

# Files in the code that match a pattern (docs, markdown and this tooling excluded).
hits() {
  git grep -ilE "$1" -- . ':!compliance.yml' ':!docs' ':!*.md' ':!scripts/compliance-profile-check.sh' \
    ':!.github' ':!.githooks' 2>/dev/null | head -3 | paste -sd, -
}
# signal <section> <key> <value that is OK> <pattern> <message>
signal() {
  local v; v=$(get "$1" "$2")
  [ "$v" = "$3" ] && return
  local found; found=$(hits "$4")
  [ -n "$found" ] && warn "$5 (seen in: $found) but $1.$2 is '${v:-empty}'"
}
signal ai used true 'openai|anthropic|langchain|llama_?index|transformers|generativeai|@google/genai|mistralai|bedrock|ollama' \
  "Code uses an AI/LLM library"
signal product sells_online true 'stripe|paypal|redsys|adyen|checkout_session' \
  "Code uses a payment provider"
signal product uses_cookies_or_trackers true 'googletagmanager|gtag\(|google-analytics|fbq\(|hotjar|mixpanel|segment\.(io|com)|posthog' \
  "Code loads analytics or tracking"
signal personal_data processed true '\b(email|e_mail|phone|telefono|dni|nif|nie|iban|birth_?date|fecha_nacimiento|address|direccion)\b' \
  "Code handles fields that look like personal data"

sc=$(get personal_data special_categories)
if [ "$sc" = "[]" ] || [ -z "$sc" ]; then
  found=$(hits 'diagnos|patient|paciente|medical|historia_clinica|biometric|fingerprint|face_?recogn|huella')
  [ -n "$found" ] && warn "Code mentions health or biometric data (seen in: $found) but personal_data.special_categories is empty"
fi

[ "$warned" -eq 0 ] && echo "[ ok ] compliance.yml looks filled and consistent with the code"
exit 0
