#!/usr/bin/env bash
# Deterministic Milestone 0 checks for the Hermes Workstation SSOT repo.
# Dependency-free beyond bash + coreutils (grep, awk, find).
# Exits 0 iff every check below passes; prints PASS/FAIL per check plus a
# final summary so the run can be pasted as evidence.

set -u
cd "$(dirname "${BASH_SOURCE[0]}")/.."
REPO_ROOT="$(pwd)"

FAIL_COUNT=0
CHECK_COUNT=0

pass() {
  CHECK_COUNT=$((CHECK_COUNT + 1))
  echo "PASS: $1"
}

fail() {
  CHECK_COUNT=$((CHECK_COUNT + 1))
  FAIL_COUNT=$((FAIL_COUNT + 1))
  echo "FAIL: $1"
}

echo "== Milestone 0 checks =="
echo "Repo root: $REPO_ROOT"
echo

# ---------------------------------------------------------------------------
# 1. Required documents exist and are non-empty
# ---------------------------------------------------------------------------
echo "-- 1. Required documents --"
REQUIRED_DOCS=(
  "BUILD_DIRECTIVE.md"
  "README.md"
  "ARCHITECTURE.md"
  "WORK_PROTOCOL.md"
  "SECURITY.md"
  "MILESTONES.md"
  "DEFINITION_OF_DONE.md"
  "DEVIATIONS.md"
  "CHANGELOG.md"
  "CLAUDE.md"
  ".gitignore"
)
for doc in "${REQUIRED_DOCS[@]}"; do
  if [ -s "$doc" ]; then
    pass "document present and non-empty: $doc"
  else
    fail "document missing or empty: $doc"
  fi
done
echo

# ---------------------------------------------------------------------------
# 2. SECURITY.md: threat model, secret model, credential locations
# ---------------------------------------------------------------------------
echo "-- 2. SECURITY.md content --"
if [ -f SECURITY.md ]; then
  if grep -qi "threat model" SECURITY.md; then
    pass "SECURITY.md declares a threat model section"
  else
    fail "SECURITY.md missing a threat model section"
  fi

  if grep -qi "secret model" SECURITY.md; then
    pass "SECURITY.md declares a secret model section"
  else
    fail "SECURITY.md missing a secret model section"
  fi

  if grep -qi "credential-bearing locations" SECURITY.md; then
    pass "SECURITY.md declares a credential-bearing-locations section"
  else
    fail "SECURITY.md missing a credential-bearing-locations section"
  fi

  for term in "Discord" "OpenAI" "Claude" "GitHub" "/opt/hermes-data"; do
    if grep -qi "$term" SECURITY.md; then
      pass "SECURITY.md credential inventory mentions: $term"
    else
      fail "SECURITY.md credential inventory missing: $term"
    fi
  done
else
  fail "SECURITY.md does not exist, cannot check content"
fi
echo

# ---------------------------------------------------------------------------
# 3. Forbidden-scope list is explicitly declared, and not implemented
# ---------------------------------------------------------------------------
echo "-- 3. Forbidden-scope declaration --"
FORBIDDEN_ITEMS=(
  "AI Project Factory"
  "separate HTTP orchestrator service"
  "second orchestrator runtime"
  "SQLite"
  "Redis"
  "message broker"
  "JobManager"
  "lease system"
  "daemon-thread"
  "DAG engine"
  "13-question"
  "event outbox"
  "watchdog daemons"
  "Kubernetes"
  "unnecessary microservices"
)
if [ -f ARCHITECTURE.md ]; then
  for item in "${FORBIDDEN_ITEMS[@]}"; do
    if grep -qi -- "$item" ARCHITECTURE.md; then
      pass "forbidden-scope item declared in ARCHITECTURE.md: $item"
    else
      fail "forbidden-scope item NOT declared in ARCHITECTURE.md: $item"
    fi
  done
else
  fail "ARCHITECTURE.md does not exist, cannot check forbidden-scope declaration"
fi

# Files allowed to mention forbidden-tech keywords because they are
# declaring them as forbidden, not using them.
ALLOWED_FORBIDDEN_MENTION_FILES="ARCHITECTURE.md|SECURITY.md|CLAUDE.md|MILESTONES.md|DEVIATIONS.md|BUILD_DIRECTIVE.md|README.md|DEFINITION_OF_DONE.md|WORK_PROTOCOL.md|CHANGELOG.md|check_milestone0.sh"
FORBIDDEN_TECH_PATTERNS=(
  "redis"
  "sqlite"
  "kafka"
  "rabbitmq"
  "kubernetes"
  "jobmanager"
)
IMPL_HITS=""
while IFS= read -r -d '' f; do
  rel="${f#$REPO_ROOT/}"
  base="$(basename "$rel")"
  if [[ "$rel" == .git/* ]]; then
    continue
  fi
  if [[ "$base" =~ ^($ALLOWED_FORBIDDEN_MENTION_FILES)$ ]]; then
    continue
  fi
  for pat in "${FORBIDDEN_TECH_PATTERNS[@]}"; do
    if grep -qi "$pat" "$f" 2>/dev/null; then
      IMPL_HITS="$IMPL_HITS\n$rel (matched: $pat)"
    fi
  done
done < <(find "$REPO_ROOT" -type f -print0)

if [ -z "$IMPL_HITS" ]; then
  pass "no forbidden technology referenced outside declaration documents"
else
  fail "forbidden technology referenced outside declaration documents:$IMPL_HITS"
fi
echo

# ---------------------------------------------------------------------------
# 4. config/*.example files: placeholders only, no real-looking secrets
# ---------------------------------------------------------------------------
echo "-- 4. config/*.example placeholder check --"
EXAMPLE_FILES=(config/*.example config/*.example.yaml config/*.example.yml)
FOUND_EXAMPLE=0
for f in "${EXAMPLE_FILES[@]}"; do
  [ -e "$f" ] || continue
  FOUND_EXAMPLE=1
  if grep -q "REPLACE_ME" "$f"; then
    pass "$f contains explicit placeholder marker"
  else
    fail "$f has no REPLACE_ME placeholder marker"
  fi

  # Flag long alnum/underscore/dash runs that are not the placeholder
  # itself and not obviously a repo-relative path/URL fragment — a crude
  # but useful signal for an accidentally-real secret.
  suspicious=$(grep -oE '[A-Za-z0-9_\.\/-]{25,}' "$f" | grep -v '^REPLACE_ME$' | grep -vE '^(config/|/opt/hermes-data)' || true)
  if [ -z "$suspicious" ]; then
    pass "$f has no real-looking secret strings"
  else
    fail "$f contains a suspicious long token-shaped string: $suspicious"
  fi
done
if [ "$FOUND_EXAMPLE" -eq 0 ]; then
  fail "no config/*.example files found"
fi

for required_example in discord openai claude github; do
  if [ -f "config/${required_example}.env.example" ]; then
    pass "config/${required_example}.env.example present"
  else
    fail "config/${required_example}.env.example missing"
  fi
done
echo

# ---------------------------------------------------------------------------
# 5. Repository tree consistency (ARCHITECTURE.md §6 vs. disk)
# ---------------------------------------------------------------------------
echo "-- 5. Repository tree consistency --"
if [ -f ARCHITECTURE.md ]; then
  TREE_BLOCK=$(awk '/^## 6\. Proposed repository tree/{flag=1} flag && /^```text$/{c++; if (c==1) {next}} flag && /^```$/{if(c==1) exit} c==1 {print}' ARCHITECTURE.md)

  M0_MISSING=0
  M0_OK=0
  FUTURE_PRESENT=0
  FUTURE_OK=0
  current_dir=""
  DIR_RE='^[A-Za-z0-9_.]+/$'
  CHILD_RE='^  ([A-Za-z0-9_./-]+)[[:space:]]+\((M[0-9])[^)]*\)$'
  TOP_RE='^([A-Za-z0-9_./-]+)[[:space:]]+\((M[0-9])[^)]*\)$'
  while IFS= read -r line; do
    [ -z "$line" ] && continue
    if [[ "$line" =~ $DIR_RE ]]; then
      current_dir="$line"
      continue
    fi
    if [[ "$line" =~ $CHILD_RE ]]; then
      fname="${BASH_REMATCH[1]}"
      mstone="${BASH_REMATCH[2]}"
      path="${current_dir}${fname}"
    elif [[ "$line" =~ $TOP_RE ]]; then
      fname="${BASH_REMATCH[1]}"
      mstone="${BASH_REMATCH[2]}"
      path="$fname"
    else
      continue
    fi

    if [ "$mstone" = "M0" ]; then
      if [ -e "$path" ]; then
        M0_OK=$((M0_OK + 1))
      else
        M0_MISSING=$((M0_MISSING + 1))
        echo "  missing M0 path declared in ARCHITECTURE.md: $path"
      fi
    else
      if [ -e "$path" ]; then
        FUTURE_PRESENT=$((FUTURE_PRESENT + 1))
        echo "  path declared for $mstone already exists (should not yet): $path"
      else
        FUTURE_OK=$((FUTURE_OK + 1))
      fi
    fi
  done <<< "$TREE_BLOCK"

  if [ "$M0_MISSING" -eq 0 ] && [ "$M0_OK" -gt 0 ]; then
    pass "all $M0_OK Milestone-0 paths in ARCHITECTURE.md's tree exist on disk"
  else
    fail "$M0_MISSING Milestone-0 path(s) declared in ARCHITECTURE.md are missing on disk"
  fi

  if [ "$FUTURE_PRESENT" -eq 0 ]; then
    pass "no Milestone 1-7 path from ARCHITECTURE.md's tree exists yet ($FUTURE_OK confirmed absent)"
  else
    fail "$FUTURE_PRESENT Milestone 1-7 path(s) already exist on disk (scope creep ahead of milestone)"
  fi
else
  fail "ARCHITECTURE.md does not exist, cannot check tree consistency"
fi
echo

# ---------------------------------------------------------------------------
# 6. Skeleton directories contain only a README.md placeholder
# ---------------------------------------------------------------------------
echo "-- 6. Skeleton directories are placeholder-only --"
for d in bootstrap docker systemd scripts; do
  if [ -d "$d" ]; then
    entries=$(find "$d" -mindepth 1 | sort)
    if [ "$entries" = "$d/README.md" ]; then
      pass "$d/ contains only README.md (no functional code yet)"
    else
      fail "$d/ contains unexpected entries: $(echo "$entries" | tr '\n' ' ')"
    fi
  else
    fail "$d/ directory does not exist"
  fi
done
echo

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo "== Summary =="
echo "Checks run: $CHECK_COUNT"
echo "Checks failed: $FAIL_COUNT"
if [ "$FAIL_COUNT" -eq 0 ]; then
  echo "RESULT: PASS"
  exit 0
else
  echo "RESULT: FAIL"
  exit 1
fi
