# 2027 Microsoft Community Calendar

A single-page calendar of 2027 Microsoft events, community conferences and regional summits across Dynamics 365, Power Platform, Microsoft 365, Fabric and Azure.

**Live site: [ajansari.github.io/msevents](https://ajansari.github.io/msevents)**

[![The 2027 Microsoft Community Calendar, showing the world map with conference pins above the filters and event table](assets/screenshot.png)](https://ajansari.github.io/msevents)

Visitors can filter events by continent, country, city, month and type, see them pinned on a world map, and jump to each event's website or call for speakers.

Created by AJ Ansari, Microsoft MVP ([onlycopilotfans.com](https://onlycopilotfans.com) · [onlybcfans.com](https://onlybcfans.com)).

## Features

- **Event table** listing the date, name, type (Conference or Regional), location and a "Speak →" link where a call for speakers is open.
- **Linked filters** for continent, country, city, month and type. Each dropdown only offers values that still match the other filters, and a Reset button clears them all.
- **World map** with one pin per city. Teal pins mark cities with at least one conference and rose pins mark cities with regional events only. Clicking a pin lists that city's events.
- **Auto-zoom**: the map shows the whole world by default and zooms to the remaining pins as filters narrow the list.
- **Responsive layout** that works on phones as well as desktops.

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

New events can be added without editing the file by hand. The work is done by the **GitHub Copilot cloud agent** in GitHub's cloud on Copilot Fusion, using two custom agents. Your own computer isn't involved.

1. **Request:** anyone opens an issue, ideally with the **Add an event** form.
2. **Approve:** a maintainer applies the `approved for build` label.
3. **Build:** the [Add event from issue](.github/workflows/add-event.yml) workflow assigns the issue to Copilot with the **Event Builder** custom agent (Copilot Fusion · Standard, the github.com default). Copilot reads the whole issue thread and researches the event: dates, location, website, call for speakers, and whether it's a Conference or a Regional event. It then adds the event to `index.html` in date order, runs the data validator and opens a pull request. When the thread conflicts, the repository owner's latest comment is the final word.
4. **Review:** when Copilot finishes and asks the owner for a review, the [Request event review](.github/workflows/review-event.yml) workflow posts an `@copilot` comment as the owner. That comment asks Copilot to review the PR as the **Event Reviewer** and to use Copilot Fusion · High. The reviewer re-checks every fact against the official sources, fixes clear-cut errors, and replies with `VERDICT: PASS` or `VERDICT: CHANGES_REQUESTED`.
5. **Publish:** nothing goes live until a maintainer merges the PR. Merging runs the [Deploy site](.github/workflows/deploy-pages.yml) workflow, which validates the data and publishes to GitHub Pages.

You can follow both sessions in the repository's **Agents** tab. If the builder can't confirm enough to add an event, it says so in the PR description (`STATUS: NEEDS_INFO`) with its questions. Answer them on the issue, close that PR, and re-apply `approved for build`, or run **Add event from issue** manually with the issue number.

| File | Purpose |
|---|---|
| [.github/workflows/add-event.yml](.github/workflows/add-event.yml) | Assigns an approved issue to Copilot with the Event Builder agent |
| [.github/workflows/review-event.yml](.github/workflows/review-event.yml) | Asks Copilot to review the finished PR as the Event Reviewer |
| [.github/workflows/deploy-pages.yml](.github/workflows/deploy-pages.yml) | Validates and deploys the site to GitHub Pages on merge to `main` |
| [.github/workflows/validate.yml](.github/workflows/validate.yml) | Validates event data on pull requests |
| [.github/agents/event-builder.agent.md](.github/agents/event-builder.agent.md) | Event Builder agent instructions |
| [.github/agents/event-reviewer.agent.md](.github/agents/event-reviewer.agent.md) | Event Reviewer agent instructions |
| [.github/copilot-instructions.md](.github/copilot-instructions.md) | Data format, date and ordering rules shared by both agents |
| [.github/scripts/validate-events.mjs](.github/scripts/validate-events.mjs) | Checks the event data parses, is well formed and is in date order |

Run the validator locally with `node .github/scripts/validate-events.mjs`.

### One-time setup

1. **Token.** Create a [fine-grained personal access token](https://github.com/settings/personal-access-tokens/new) owned by your account, with access to this repository only. Give it **Read** access to Metadata and **Read and write** access to Actions, Contents, Issues and Pull requests. Save it as the repository secret `COPILOT_ASSIGN_TOKEN` (**Settings → Secrets and variables → Actions**). It assigns issues to Copilot and posts the review request as you, because Copilot only takes work from people with write access.
2. **Web access for Copilot.** Copilot's cloud firewall blocks most of the internet by default, which would stop it researching event sites. In **Settings → Copilot → Cloud agent** (internet access), either turn the firewall off for this repository or add the event sites you want it to reach to the allowlist.
3. **Pages.** In **Settings → Pages → Build and deployment**, set **Source** to **GitHub Actions**.
4. **Copilot's workflow runs.** If GitHub asks you to approve workflow runs on Copilot's pull requests, approve them, or allow Copilot's workflows to run without approval in the Copilot cloud agent settings.

The model comes from the github.com default (Copilot Fusion · Standard). To pin a specific model value for the build, set the repository variable `COPILOT_BUILD_MODEL`. GitHub doesn't currently document a way to set Fusion's effort level when assigning work through the API, so the reviewer's "High" is requested in its instructions and may not be honoured.

## Disclaimer

This is an independent community project. It is not created, sponsored or endorsed by Microsoft, and it is not affiliated with Microsoft. Microsoft and the Microsoft logo are trademarks of the Microsoft group of companies, used here only to identify the events and products this calendar covers. All other names and logos belong to their respective owners.

## Contributing

This is an open-source project, and corrections and additions are welcome. If an event is missing, has moved or has confirmed its dates, open an issue or send a pull request that edits the `EVENTS` array as described above.

## License

Released under the [MIT License](LICENSE).
