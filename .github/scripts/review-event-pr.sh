#!/usr/bin/env bash
# Moves one Copilot event pull request along: request the Event Reviewer, act on its verdict.
# Called by .github/workflows/review-event.yml after its "check" job.
#
# Usage: review-event-pr.sh <pr-number> <check-dir>
#   <check-dir> holds the check job's results: sha, state (success|failure|empty), detail, issues.json
# Env: GITHUB_REPOSITORY, DECISION_MAKER (owner login), OWNER_TOKEN (posts the @copilot request as the owner),
#      BOT_TOKEN (reads, labels, statuses, notices), DRY_RUN=1 to print writes instead of making them.
set -eo pipefail

pr="$1"; dir="$2"
R="$GITHUB_REPOSITORY"
MARKER='<!-- event-reviewer-requested -->'
L_PASS='review: passed'; L_CHANGES='review: changes requested'; L_CHECKS='review: checks failed'
L_STALLED='review: stalled'; L_INFO='needs info'
MAX_REQUESTS=3          # review requests per PR before giving up and asking a human
STALL_MINUTES=90        # a Copilot session running longer than this is treated as stuck
PICKUP_MINUTES=20       # a request Copilot hasn't started on after this is sent again

read_gh() { GH_TOKEN="$BOT_TOKEN" gh "$@"; }
write_gh() {            # $1 = owner|bot, rest = gh arguments
  local who="$1"; shift
  if [ -n "$DRY_RUN" ]; then echo "DRY RUN ($who): gh $*" >&2; return 0; fi
  if [ "$who" = owner ]; then GH_TOKEN="$OWNER_TOKEN" gh "$@"; else GH_TOKEN="$BOT_TOKEN" gh "$@"; fi
}
minutes_since() { jq -nr --arg t "$1" '((now - ($t | sub("\\.[0-9]+Z$"; "Z") | fromdateiso8601)) / 60) | floor'; }
has_label() { case ",$labels," in *",$1,"*) return 0 ;; *) return 1 ;; esac; }
add_label() { has_label "$1" || write_gh bot pr edit "$pr" --repo "$R" --add-label "$1" > /dev/null; }
drop_label() { if has_label "$1"; then write_gh bot pr edit "$pr" --repo "$R" --remove-label "$1" > /dev/null; fi; }
set_review_status() {   # $1 = success|failure, $2 = description
  write_gh bot api -X POST "repos/$R/statuses/$sha" -f state="$1" -f context="event-review" \
    -f description="$2" -f target_url="$GITHUB_SERVER_URL/$R/pull/$pr" > /dev/null
}
notice() { write_gh bot pr comment "$pr" --repo "$R" --body "$1" > /dev/null; }
stall() {               # label the PR as needing a human, once
  if has_label "$L_STALLED"; then echo "Already marked stalled."; exit 0; fi
  add_label "$L_STALLED"
  notice "⚠️ **Event review stalled:** $1

The automation has stopped working on this PR. Check the **Agents** tab, then either reply \`@copilot …\` yourself or close this PR and re-apply \`approved for build\` on the issue. Remove the \`$L_STALLED\` label to let the automation try again."
  echo "Stalled: $1"; exit 0
}

sha=$(cat "$dir/sha"); checks=$(cat "$dir/state"); detail=$(cat "$dir/detail")
info=$(read_gh pr view "$pr" --repo "$R" --json isDraft,labels,headRefOid,state \
         --jq '"\(.state)|\(.isDraft)|\(.headRefOid)|\([.labels[].name] | join(","))"')
IFS='|' read -r prstate draft head labels <<<"$info"
[ "$prstate" = "OPEN" ] || { echo "PR is $prstate."; exit 0; }
[ "$head" = "$sha" ] || { echo "New commits since the check ran; the next run handles them."; exit 0; }
if has_label "$L_STALLED"; then echo "Marked stalled; remove the label to resume."; exit 0; fi
issues=$(jq -r 'if length == 0 then "none linked" else [.[] | "#\(.number)"] | join(", ") end' "$dir/issues.json")

# 1. Wait while Copilot is working. Any copilot_work_* event other than "started" ends a session.
timeline=$(read_gh api "repos/$R/issues/$pr/timeline" --paginate \
             --jq '.[] | select(.event // "" | startswith("copilot_work")) | {e: .event, t: .created_at}' | jq -s .)
last_event=$(jq -r 'last.e // ""' <<<"$timeline"); last_t=$(jq -r 'last.t // ""' <<<"$timeline")
if [ -z "$last_event" ]; then echo "No Copilot session on this PR yet."; exit 0; fi
if [ "$last_event" = "copilot_work_started" ]; then
  age=$(minutes_since "$last_t")
  [ "$age" -lt "$STALL_MINUTES" ] && { echo "Copilot is working (for $age min)."; exit 0; }
  stall "Copilot's session started $age minutes ago and hasn't finished."
fi

# 2. This exact commit already has a decision: leave the PR alone, whatever a human does to it.
decided=$(read_gh api "repos/$R/commits/$sha/statuses" --jq '[.[] | select(.context == "event-review")][0].state // ""')
case "$decided" in success|failure) echo "Commit ${sha:0:7} already decided ($decided)."; exit 0 ;; esac

# 3. Copilot changed nothing: nothing to review.
if [ "$checks" = "empty" ]; then
  if ! has_label "$L_INFO"; then
    add_label "$L_INFO"
    notice "ℹ️ Copilot made no changes, so there's nothing to review. Its questions or reasons should be in the PR description. Answer them on the issue, close this PR, and re-apply \`approved for build\`."
  fi
  echo "No changes; labelled $L_INFO."; exit 0
fi

# 4. Find the latest review request (owner's comments only) and Copilot's latest verdict after it.
comments=$(read_gh api "repos/$R/issues/$pr/comments" --paginate --jq '.[] | {u: .user.login, t: .created_at, b: .body}' | jq -s .)
requests=$(jq --arg m "$MARKER" --arg o "$DECISION_MAKER" '[.[] | select(.u == $o and (.b | contains($m)))] | length' <<<"$comments")
last_req=$(jq -r --arg m "$MARKER" --arg o "$DECISION_MAKER" '[.[] | select(.u == $o and (.b | contains($m))) | .t] | last // ""' <<<"$comments")
verdict_json=$(jq -c --arg after "$last_req" '
  [ .[] | select(.u == "Copilot" and .t > $after)
    | { t, report: (.b | split("\n") | any(.[]; test("^#+ *Event Reviewer report"))),
        v: ([.b | split("\n")[] | gsub("[*`>]"; "") | sub("^\\s+"; "") | sub("[\\s.]+$"; "")
             | select(test("^VERDICT: *(PASS|CHANGES_REQUESTED)$")) | sub("^VERDICT: *"; "")] | last) }
    | select(.v != null) ] | last // {}' <<<"$comments")
verdict=$(jq -r '.v // ""' <<<"$verdict_json"); verdict_t=$(jq -r '.t // ""' <<<"$verdict_json")
report=$(jq -r '.report // false' <<<"$verdict_json")
head_t=$(read_gh api "repos/$R/commits/$sha" --jq .commit.committer.date)
echo "Checks: $checks. Requests: $requests (last $last_req). Verdict: ${verdict:-none} at ${verdict_t:-–} (report format: $report). Head commit: $head_t."

note=""
if [ -n "$verdict" ] && [[ "$verdict_t" > "$head_t" || "$verdict_t" == "$head_t" ]]; then
  # The verdict covers the current commit.
  if [ "$report" != "true" ]; then
    note="Your previous reply didn't use the Event Reviewer's report format, so it may not have been done by the Event Reviewer agent. Please run the full Event Reviewer review."
  elif [ "$verdict" = "PASS" ] && [ "$checks" = "success" ]; then
    add_label "$L_PASS"; drop_label "$L_CHANGES"; drop_label "$L_CHECKS"; drop_label "$L_INFO"
    [ "$draft" = "true" ] && write_gh owner pr ready "$pr" --repo "$R"
    set_review_status success "Event Reviewer passed ${sha:0:7}"
    echo "Passed: PR #$pr is ready to merge."; exit 0
  elif [ "$verdict" = "PASS" ]; then
    add_label "$L_CHECKS"
    note="Your review passed, but the automated checks failed on this commit:
\`\`\`
$detail
\`\`\`
Fix what they report (event data in \`index.html\` only), then review again."
  else
    add_label "$L_CHANGES"; drop_label "$L_PASS"
    [ "$draft" = "false" ] && write_gh owner pr ready "$pr" --repo "$R" --undo
    set_review_status failure "Event Reviewer asked for changes on ${sha:0:7}"
    notice "🔁 **The Event Reviewer asked for changes** (see its report above), so this PR stays a draft.

- **To fix it:** reply \`@copilot\` with what to change. When Copilot pushes new commits, the review runs again automatically.
- **To accept it as it is:** mark the PR ready and merge it yourself."
    echo "Changes requested; left as draft."; exit 0
  fi
else
  if [ "$requests" -eq 0 ]; then
    :
  elif [ -n "$verdict" ]; then
    note="There are new commits since your last verdict. Please review the pull request again as it is now."
  elif jq -e --arg after "$last_req" 'any(.[]; .e == "copilot_work_started" and .t > $after)' <<<"$timeline" > /dev/null; then
    note="Your previous session ended without a \`VERDICT:\` line. Please finish the review."
  elif [ "$(minutes_since "$last_req")" -ge "$PICKUP_MINUTES" ]; then
    note="(Repeating the request: Copilot didn't start on the previous one.)"
  else
    echo "Review requested $(minutes_since "$last_req") min ago; waiting for Copilot."; exit 0
  fi
fi

# 5. Ask (again) for the review.
[ "$requests" -ge "$MAX_REQUESTS" ] && stall "Copilot was asked $requests times without a usable verdict for commit ${sha:0:7}."
drop_label "$L_PASS"
[ "$draft" = "false" ] && write_gh owner pr ready "$pr" --repo "$R" --undo
if [ "$checks" = "failure" ] && [ "$verdict" != "PASS" -o "$report" != "true" ]; then
  note="${note:+$note

}The automated checks currently fail on this commit:
\`\`\`
$detail
\`\`\`
Fix what they report (event data in \`index.html\` only) as part of your review."
fi

body=$(cat <<EOF
@copilot Please review this pull request now as the **Event Reviewer**, before it goes live.

1. **Run this review with the \`event-reviewer\` custom agent.** Use your \`task\` tool to hand the whole review to it. If you can't, read \`.github/agents/event-reviewer.agent.md\` before anything else and follow it exactly.
2. **Use Copilot Fusion at High effort for this review.** This is @$DECISION_MAKER's preference.
3. Review independently. Re-check every fact against the official sources, and don't rely on the build summary or on stored memories.
4. The issue(s) this PR closes: $issues. @$DECISION_MAKER's most recent comment there is the final word.
5. Start your reply with the line \`## Event Reviewer report\`. End it with a line that is exactly \`VERDICT: PASS\` or \`VERDICT: CHANGES_REQUESTED\`.
${note:+
$note
}
$MARKER
EOF
)
write_gh owner pr comment "$pr" --repo "$R" --body "$body" > /dev/null
[ -n "$DRY_RUN" ] && printf '%s\n' "--- request body ---" "$body"
echo "Asked Copilot to review PR #$pr (request $((requests + 1)) of $MAX_REQUESTS)."
