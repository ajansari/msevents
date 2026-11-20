# Project instructions for Copilot

This repository is the **2027 Microsoft Community Calendar**, published at <https://ajansari.github.io/msevents>. The whole site is one self-contained file, `index.html`, with inline CSS, JavaScript, images and map. There is no build step and no dependencies. Do not add any.

## Where the event data lives

All event data is in the `<script>` block at the bottom of `index.html`, between `const ROADSHOW` and `const EXT_ICON`. Keep both of those lines; the validator uses them as markers.

- `EVENTS` is an array with one object per event, **in date order**. The table renders it in exactly that order.
- `COORDS` maps each city name to `[latitude, longitude]` in decimal degrees (2 decimal places). Every non-TBA city used by an event must have an entry here, or it gets no map pin.
- `ROADSHOW`, `REGIONALS` and `DFP_SPEAK` are shared URLs reused by several events. Reuse them when an event belongs to that series.

Match the existing code style exactly: one event per line, the same key order (`d, m, n, tag, t, city, loc, country, cont, url, cfs`), double quotes, and the column alignment used by neighbouring lines where practical.

## Event fields

| Field | Required | Rule |
|---|---|---|
| `d` | Yes | Display date (see the date formats below). |
| `m` | Yes | Full English name of the month the event **starts** in, or `"TBA"`. |
| `n` | Yes | Event name, as the organiser writes it, including the year when they do (e.g. `"DynamicsCon 2027"`). |
| `tag` | No | Short subtitle: what the acronym means, the venue, or an audience restriction. Separate parts with ` · `. |
| `t` | Yes | `"Conference"` or `"Regional"` (see below). |
| `city` | Yes | City used by the City filter and the map, e.g. `"Las Vegas"`, or `"TBA"`. Must match a `COORDS` key. |
| `loc` | Yes | Location as displayed. US and Canadian cities include the state or province code (`"Las Vegas, NV"`, `"Toronto, ON"`); cities elsewhere are the city name alone (`"Dublin"`). Use `"To be announced"` when unknown. |
| `country` | Yes | Country name as already used in the file (`"USA"`, `"Canada"`, `"Germany"`…), or `"TBA"`. |
| `cont` | Yes | One of `North America`, `South America`, `Europe`, `Asia`, `Africa`, `Oceania`, `Middle East`, or `TBA`. Central America and the Caribbean count as `North America`, as in the existing data. |
| `url` | No | Official event website (https). Omit the field if there is no official site. |
| `cfs` | No | Official call-for-speakers / call-for-papers page (often Sessionize). Omit when there isn't one or it is not open/announced. |

When the location is unknown, set `city`, `country` and `cont` to `"TBA"` and `loc` to `"To be announced"`.

## Date formats

All events are in 2027. Use a three-letter month abbreviation and an **en dash** (`–`, U+2013), never a hyphen.

| Situation | `d` | `m` |
|---|---|---|
| Single day | `"Feb 9"` | `"February"` |
| Range within one month | `"Mar 8–12"` (no spaces around the dash) | `"March"` |
| Range across two months | `"Mar 30 – Apr 1"` (spaces around the dash) | `"March"` (the start month) |
| Only the month is known | `"March"` | `"March"` |
| Date not known at all | `"TBA"` | `"TBA"` |

## Ordering

Insert each event so `EVENTS` stays sorted by start date:

1. By start month (January → December).
2. Within a month, by start day. Month-only entries (`d:"March"`) go **after** all dated entries for that month.
3. Events with the same start date keep insertion order; put the new one after the existing ones.
4. `TBA` events go at the very end.

## Conference or Regional

- **Conference**: a standalone, named conference with its own brand, usually multi-day and multi-track, that draws people from a wide area (e.g. FabCon, DynamicsCon, Directions North America/EMEA/ASIA, ECS, BC TechDays, Microsoft MVP Summit, Microsoft Build).
- **Regional**: a local or regional edition of a larger series, a roadshow or tour stop, a user-group day, or a one-day event aimed at one city or region (e.g. Community Summit Roadshow stops, DynamicsCon Regionals, Days of Knowledge regional editions).

When in doubt, follow how the same organiser's other events are classified in the file, and say in your summary why you chose the type.

## Checking your work

Run `node .github/scripts/validate-events.mjs` after editing. It must print a line starting with `✓`. It checks the data parses, required fields, date formats, `m` matching `d`, map coordinates, duplicates and date order.

## Accuracy

Only add facts you found on an authoritative source: the organiser's official site, its official call-for-speakers page, or an official announcement. Never invent or guess a date, venue, or URL. If a fact can't be confirmed, use the TBA/month-only conventions above or leave optional fields out, and say so in your summary.
