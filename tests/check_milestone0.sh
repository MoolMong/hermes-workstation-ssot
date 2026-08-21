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
ALLOWED_FORBIDDEN_MENTION_FILES="ARCHITECTURE.md|SECURITY.md|CLAUDE.md|MILESTONES.md|DEVIATIONS.md|BUILD_DIRECTIVE.md|README.md|DEFINITION_OF_DONE.md|WORK_PROTOCOL.md|CHANGELOG.md|check_milestone0.sh|MILESTONE2_DIRECTIVE.md"
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
  # Per WORK_PROTOCOL.md, milestone TASK.md files must state constraints and
  # exclusions explicitly. Mentioning forbidden components there documents
  # that they are prohibited; it is not implementation evidence.
  if [[ "$rel" == evidence/milestone-*/TASK.md ]]; then
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
# 5. Repository tree consistency (ARCHITECTURE.md §6 vs. disk), milestone-
#    aware so this script keeps being a meaningful regression check after
#    Milestone 0 instead of permanently expecting an Milestone-0-only tree.
#
#    CURRENT_MILESTONE is the highest milestone whose implementation has
#    started in this repository. Bump it in the same change that starts a
#    new milestone's implementation, and only then. It is deliberately a
#    plain constant, not derived by parsing prose out of MILESTONES.md —
#    the sanity check right below cross-checks it against MILESTONES.md's
#    status table instead, so a forgotten bump (or a bump with no matching
#    status-table update) fails loudly rather than silently drifting.
# ---------------------------------------------------------------------------
CURRENT_MILESTONE=2

echo "-- 5. Repository tree consistency --"

# 5a. CURRENT_MILESTONE must match MILESTONES.md's own status table: the
# row for CURRENT_MILESTONE must not say "Planned", and (unless it's the
# last milestone) the row for CURRENT_MILESTONE+1 must still say "Planned".
# This keeps the constant above honest without needing this script to
# parse arbitrary status prose to derive it.
if [ -f MILESTONES.md ]; then
  milestone_status() {
    awk -F'|' -v n="$1" '{
      gsub(/^[ \t]+|[ \t]+$/, "", $2);
      if ($2 == n) { gsub(/^[ \t]+|[ \t]+$/, "", $4); print $4; exit }
    }' MILESTONES.md
  }
  cur_status="$(milestone_status "$CURRENT_MILESTONE")"
  if [ -n "$cur_status" ] && ! echo "$cur_status" | grep -qi 'planned'; then
    pass "MILESTONES.md marks milestone $CURRENT_MILESTONE as not-Planned (status: $cur_status), matching CURRENT_MILESTONE=$CURRENT_MILESTONE in this script"
  else
    fail "MILESTONES.md status for milestone $CURRENT_MILESTONE is '$cur_status' — does not confirm CURRENT_MILESTONE=$CURRENT_MILESTONE in this script; update MILESTONES.md or this constant together"
  fi
  if [ "$CURRENT_MILESTONE" -lt 7 ]; then
    next_status="$(milestone_status "$((CURRENT_MILESTONE + 1))")"
    if echo "$next_status" | grep -qi 'planned'; then
      pass "MILESTONES.md still marks milestone $((CURRENT_MILESTONE + 1)) as Planned (sequencing rule respected)"
    else
      fail "MILESTONES.md status for milestone $((CURRENT_MILESTONE + 1)) is '$next_status', not Planned — either that milestone started (bump CURRENT_MILESTONE in this script) or MILESTONES.md regressed"
    fi
  fi
else
  fail "MILESTONES.md does not exist, cannot cross-check CURRENT_MILESTONE"
fi

if [ -f ARCHITECTURE.md ]; then
  TREE_BLOCK=$(awk '/^## 6\. Proposed repository tree/{flag=1} flag && /^```text$/{c++; if (c==1) {next}} flag && /^```$/{if(c==1) exit} c==1 {print}' ARCHITECTURE.md)

  CUR_MISSING=0
  CUR_OK=0
  FUTURE_PRESENT=0
  FUTURE_OK=0
  # path -> milestone, for every path declared anywhere in the tree,
  # regardless of milestone. Used by section 6 to detect undeclared files.
  DECLARED_PATHS=()
  DECLARED_MSTONES=()
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

    DECLARED_PATHS+=("$path")
    DECLARED_MSTONES+=("$mstone")

    mstone_num="${mstone#M}"
    if [ "$mstone_num" -le "$CURRENT_MILESTONE" ]; then
      if [ -e "$path" ]; then
        CUR_OK=$((CUR_OK + 1))
      else
        CUR_MISSING=$((CUR_MISSING + 1))
        echo "  missing $mstone path declared in ARCHITECTURE.md: $path"
      fi
    else
      if [ -e "$path" ]; then
        FUTURE_PRESENT=$((FUTURE_PRESENT + 1))
        echo "  path declared for $mstone already exists (should not yet, current milestone is M$CURRENT_MILESTONE): $path"
      else
        FUTURE_OK=$((FUTURE_OK + 1))
      fi
    fi
  done <<< "$TREE_BLOCK"

  if [ "$CUR_MISSING" -eq 0 ] && [ "$CUR_OK" -gt 0 ]; then
    pass "all $CUR_OK Milestone 0-$CURRENT_MILESTONE paths in ARCHITECTURE.md's tree exist on disk"
  else
    fail "$CUR_MISSING path(s) declared for Milestone 0-$CURRENT_MILESTONE in ARCHITECTURE.md are missing on disk"
  fi

  if [ "$FUTURE_PRESENT" -eq 0 ]; then
    pass "no path beyond Milestone $CURRENT_MILESTONE from ARCHITECTURE.md's tree exists yet ($FUTURE_OK confirmed absent)"
  else
    fail "$FUTURE_PRESENT path(s) beyond Milestone $CURRENT_MILESTONE already exist on disk (scope creep ahead of milestone)"
  fi
else
  fail "ARCHITECTURE.md does not exist, cannot check tree consistency"
fi
echo

# ---------------------------------------------------------------------------
# 6. Skeleton directories contain only what ARCHITECTURE.md's tree declares
#    for Milestone 0-$CURRENT_MILESTONE — no undeclared or future-milestone
#    files. This replaces the Milestone-0-only "only a README.md" check:
#    that check would itself now be a false failure once Milestone 1 adds
#    real files, without actually catching any real scope-creep risk that
#    section 5's future-path check doesn't already cover.
# ---------------------------------------------------------------------------
echo "-- 6. Skeleton directories contain no undeclared files --"
for d in bootstrap docker systemd scripts; do
  if [ -d "$d" ]; then
    entries=$(find "$d" -mindepth 1 -type f | sort)
    undeclared=""
    while IFS= read -r entry; do
      [ -z "$entry" ] && continue
      declared=0
      for p in "${DECLARED_PATHS[@]}"; do
        [ "$p" = "$entry" ] && { declared=1; break; }
      done
      [ "$declared" -eq 0 ] && undeclared="$undeclared $entry"
    done <<< "$entries"
    if [ -z "$undeclared" ]; then
      pass "$d/ contains only files declared in ARCHITECTURE.md's tree (no undeclared/scope-creep files)"
    else
      fail "$d/ contains file(s) not declared in ARCHITECTURE.md's tree:$undeclared"
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
