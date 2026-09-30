#!/bin/bash
# Installs pre-commit and pre-push git hooks that run scripts/check-public.sh,
# so a private profile or a denylisted term cannot be committed or pushed by
# accident. Run it once per clone. Existing hooks are backed up, not replaced.
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
hooks="$(git -C "$root" rev-parse --git-path hooks)"
case "$hooks" in /*) ;; *) hooks="$root/$hooks" ;; esac
mkdir -p "$hooks"

for h in pre-commit pre-push; do
  if [ -f "$hooks/$h" ] && ! grep -q 'check-public.sh' "$hooks/$h"; then
    mv "$hooks/$h" "$hooks/$h.bak-$(date +%Y%m%d%H%M%S)"
    echo "backed up existing $h"
  fi
  cat > "$hooks/$h" <<'EOF'
#!/bin/bash
# Installed by scripts/install-git-hooks.sh
exec bash "$(git rev-parse --show-toplevel)/scripts/check-public.sh"
EOF
  chmod +x "$hooks/$h"
  echo "installed $h -> scripts/check-public.sh"
done
