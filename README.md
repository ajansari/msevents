# 2027 Microsoft Community Calendar

A single-page calendar of 2027 Microsoft events, community conferences and regional summits across Dynamics 365, Power Platform, Microsoft 365, Fabric and Azure.

**Live site: [ajansari.github.io/msevents](https://ajansari.github.io/msevents)**

[![The 2027 Microsoft Community Calendar, showing the world map with conference pins above the filters and event table](assets/screenshot.png)](https://ajansari.github.io/msevents)

Visitors can filter events by continent, country, city, month and type, see them pinned on a world map, and jump to each event's website or call for speakers.

Created by AJ Ansari, Microsoft MVP ([onlycopilotfans.com](https://onlycopilotfans.com) · [onlybcfans.com](https://onlybcfans.com)).

## Features

- **Event table** listing the date, name, type (Conference or Regional), location and a "Speak →" link where a call for speakers is open.
- **Linked filters** for continent, country, city, month and type. Each dropdown only offers values that still match the other filters, and a **Reset filters** button clears them all.
- **World map** with one pin per city. Teal pins mark cities with at least one conference and rose pins mark cities with regional events only. Clicking a pin lists that city's events.
- **Auto-zoom**: the map shows the whole world by default and zooms to the remaining pins as filters narrow the list.
- **Responsive layout** that works on phones as well as desktops.
- **Build Your Own 2027 Conference Calendar**: visitors build a personal calendar and take it with them. The panel is collapsed until they open it.
  - Each event has **Going** and **Maybe** buttons. Clicking the active one again clears it.
  - Entering a name titles the calendar, for example "Bob Johnson's 2027 Conference Calendar".
  - **Save as PDF** opens the browser's print window with a print layout on a white background, in Letter or A4, with clean page breaks.
  - **Download web page** saves the same calendar as one self-contained HTML file.
  - Both can include or skip the map, and list events by date or as Going first, then Maybe.
  - Only events marked Going or Maybe are included, and only those matching the filters in use.
  - **Reset and Start Over** clears the name and picks.
  - Name, picks and options are remembered in the visitor's browser only (`localStorage`). Nothing is sent anywhere. Picks follow an event's name, so renaming an event drops visitors' picks for it.

## Running it

The whole project is one file, [index.html](index.html), with no build step, dependencies or network requests. The styles, script, logos and world map are all inline.

To view it locally, open `index.html` in a browser. The live site at <https://ajansari.github.io/msevents> is deployed to GitHub Pages by the [Deploy site](.github/workflows/deploy-pages.yml) workflow whenever `main` changes. The file works on any other static host too.

## Updating the events

All data lives in the `<script>` block at the bottom of [index.html](index.html).

### Add or edit an event

Each event is one object in the `EVENTS` array. Keep the array in date order, because the table renders it as written.

```js
{d:"May 17–20", m:"May", n:"DynamicsCon 2027", t:"Conference",
 city:"Las Vegas", loc:"Las Vegas, NV", country:"USA", cont:"North America",
 url:"https://dynamicscon.com/", cfs:"https://sessionize.com/dynamicscon-2027"}
```

| Field | Required | Meaning |
|---|---|---|
| `d` | Yes | Date as displayed, such as `"Feb 9"` or `"Mar 8–12"`. Use the month name alone for preliminary dates, or `"TBA"`. |
| `m` | Yes | Full month name used by the Month filter, or `"TBA"`. |
| `n` | Yes | Event name. |
| `t` | Yes | `"Conference"` or `"Regional"`. |
| `city` | Yes | City used by the City filter and the map pin. Must match a key in `COORDS`. |
| `loc` | Yes | Location as displayed, such as `"Irving (Dallas), TX"`. |
| `country` | Yes | Country used by the Country filter. |
| `cont` | Yes | Continent used by the Continent filter. |
| `url` | No | Event website. Without it, the name is shown as plain text. |
| `cfs` | No | Call-for-speakers link, shown as "Speak →". |
| `tag` | No | Short subtitle under the event name, such as the venue. |

Events without confirmed details use `"TBA"` for `d`, `m`, `city`, `country` and `cont`. They appear in the table but not on the map.

### Add a new city

A pin appears only if the event's `city` has an entry in `COORDS`, as `[latitude, longitude]` in decimal degrees:

```js
"Budapest":[47.50,19.04]
```

### Shared links

The `ROADSHOW`, `REGIONALS` and `DFP_SPEAK` constants at the top of the script hold URLs shared by several events. Change them once to update every event that uses them.

## How the map works

The world outline is an inline SVG path drawn in a simple equirectangular projection, where x is longitude × 10 and y is −latitude × 10. `drawMap()` sets the SVG `viewBox` to frame the filtered cities, then positions each pin as an HTML button over the map using the same longitude and latitude maths. The map redraws when the window is resized.

## Notes on the data

- All dates are for 2027 and are subject to change.
- Entries that show only a month are preliminary.
- Microsoft Build and Microsoft Ignite 2027 dates and venues have not been announced by Microsoft.

## Automation: from issue to live event

New events can be added without editing the file by hand. The work is done by the **GitHub Copilot cloud agent** in GitHub's cloud, using two custom agents. Your own computer isn't involved, and the only human steps are approving the issue and merging the result.

1. **Request:** anyone opens an issue, ideally with the **Add an event** form, which labels it `event request`.
2. **Approve:** a maintainer applies the `approved for build` label. This is the recommended way to start a build. Alternatively, assign the issue to Copilot by hand (**Assignees → Copilot**) and pick the **Event Builder** agent; the rest of the pipeline works the same.
3. **Build:** the [Add event from issue](.github/workflows/add-event.yml) workflow assigns the issue to Copilot with the **Event Builder** custom agent.
   - Copilot reads the whole issue thread. When it conflicts, the repository owner's latest comment is the final word.
   - It researches the dates, location, website and call for speakers, and decides whether it's a Conference or a Regional event.
   - It adds the event to `index.html` in date order, runs the validator and opens a draft pull request.
4. **Check:** the [Request event review](.github/workflows/review-event.yml) workflow runs `main`'s validator on the pull request, with no secrets available. It also confirms that only the event data in `index.html` changed and that no value carries markup or a non-https link. The result appears on the PR as the `event-checks` status.
5. **Review:** each time a Copilot session finishes, the build workflow's follow-up job starts **Request event review**. A 10-minute schedule is the backup. The workflow posts an `@copilot` comment as the owner, asking Copilot to hand the review to the **Event Reviewer** agent. The reviewer re-checks every fact against the official sources, fixes clear-cut errors, and replies with an `## Event Reviewer report` that ends in `VERDICT: PASS` or `VERDICT: CHANGES_REQUESTED`.
6. **Ready:** what happens next depends on the verdict:
   - **`PASS`, with `event-checks` passing:** the PR leaves draft, is labelled `review: passed` and gets the `event-review` status.
   - **`CHANGES_REQUESTED`:** the PR stays a draft, is labelled `review: changes requested`, and you're notified. Reply `@copilot` with what to change. Copilot's new commits are reviewed again automatically.
   - **Commits pushed after any verdict:** they always trigger a fresh review.
7. **Publish:** nothing goes live until a maintainer merges the PR. Merging runs the [Deploy site](.github/workflows/deploy-pages.yml) workflow, which validates the data and publishes to GitHub Pages.

The automation labels anything it can't finish:

| Label | Meaning |
|---|---|
| `needs info` | Copilot couldn't confirm enough to add the event, so it made no change. Answer its questions on the issue, close the PR and re-apply `approved for build`. |
| `review: checks failed` | The reviewer passed the PR but the automated checks didn't. The reviewer is asked to fix them. |
| `review: stalled` | A Copilot session ran for more than 90 minutes, or three review requests produced no usable verdict. Look at the **Agents** tab, then remove the label to let the automation try again. |

Re-applying `approved for build` while a Copilot PR for the issue is still open does nothing, so you don't get duplicates. To rebuild anyway, run **Add event from issue** with **force** ticked. If the automation itself breaks, for example because the token expired, it opens an issue titled *Event automation needs attention*.

| File | Purpose |
|---|---|
| [.github/workflows/add-event.yml](.github/workflows/add-event.yml) | Assigns an approved issue to Copilot with the Event Builder agent, then starts the review each time a Copilot session finishes |
| [.github/workflows/review-event.yml](.github/workflows/review-event.yml) | Checks event PRs, requests the Event Reviewer and acts on its verdict |
| [.github/scripts/review-event-pr.sh](.github/scripts/review-event-pr.sh) | The steps that move one PR from built to ready |
| [.github/workflows/deploy-pages.yml](.github/workflows/deploy-pages.yml) | Validates and deploys the site to GitHub Pages on merge to `main` |
| [.github/workflows/validate.yml](.github/workflows/validate.yml) | Validates event data on pull requests |
| [.github/agents/event-builder.agent.md](.github/agents/event-builder.agent.md) | Event Builder agent instructions |
| [.github/agents/event-reviewer.agent.md](.github/agents/event-reviewer.agent.md) | Event Reviewer agent instructions |
| [.github/copilot-instructions.md](.github/copilot-instructions.md) | Data format, date, ordering and safety rules shared by both agents |
| [.github/scripts/validate-events.mjs](.github/scripts/validate-events.mjs) | Checks the event data is plain, safe, well formed and in date order (and, with `--base`, that nothing else changed) |

Run the validator locally with `node .github/scripts/validate-events.mjs`.

### One-time setup

1. **Token.** Create a [fine-grained personal access token](https://github.com/settings/personal-access-tokens/new) owned by your account, with access to this repository only.
   - Permissions: **Read** for Metadata, **Read and write** for Actions, Contents, Issues and Pull requests.
   - Save it as the repository secret `COPILOT_ASSIGN_TOKEN` (**Settings → Secrets and variables → Actions**).
   - It assigns issues to Copilot and posts the review request as you, because Copilot only takes work from people with write access.
   - Note its expiry date. When it expires, the automation opens an issue telling you to replace it.
2. **Web access for Copilot.** Copilot's cloud firewall blocks most of the internet by default, which would stop it researching event sites. In **Settings → Copilot → Cloud agent** (internet access), either turn the firewall off for this repository or add the event sites you want it to reach to the allowlist. The allowlist is safer, because with the firewall off Copilot reads any page an issue points it to.
3. **Pages.** In **Settings → Pages → Build and deployment**, set **Source** to **GitHub Actions**.
4. **Protect `main` (recommended).** In **Settings → Rules → Rulesets**, add a branch ruleset for `main` with **Require a pull request before merging** (0 approvals) and **Block force pushes**. Leave the bypass list empty. Then neither the token nor anyone else can push to `main` without a pull request. Before you merge an event PR, check that its `event-checks` status is green.

You don't need to approve Copilot's own workflow runs; the pipeline doesn't depend on them.

GitHub turns off scheduled workflows in public repositories after 60 days without activity. The schedule is only a backup, but if **Request event review** shows as disabled under **Actions**, enable it again.

**Models.** Copilot's cloud agent uses your github.com default model. GitHub doesn't document a way to choose the model or Fusion's effort level for a review requested in a PR comment, so the reviewer's "Fusion · High" is requested in writing and may not be honoured. The review also runs on the same model setting as the build. To check which model a session used, open it in the **Agents** tab. To pin a model for the build, set the repository variable `COPILOT_BUILD_MODEL`, or assign the issue by hand and choose the model there.

## Disclaimer

This is an independent community project. It is not created, sponsored or endorsed by Microsoft, and it is not affiliated with Microsoft. Microsoft and the Microsoft logo are trademarks of the Microsoft group of companies, used here only to identify the events and products this calendar covers. All other names and logos belong to their respective owners.

## Contributing

This is an open-source project, and corrections and additions are welcome. If an event is missing, has moved or has confirmed its dates, open an issue or send a pull request that edits the `EVENTS` array as described above.

## License

Released under the [MIT License](LICENSE).
