# KOReader Cat Log

A [KOReader](https://koreader.rocks/) plugin for one-tap logging of a cat's litterbox habits and accidents on an e-ink device. It was built for a jailbroken Kindle used as a dedicated tracking tablet, but it should work anywhere KOReader runs.

> **Status:** early release (v0.2.0). Developed for a Kindle Paperwhite 7th generation (firmware 5.16.2.1.1) running KOReader. It has not yet been widely tested, so please open an issue if something breaks.

## Features

- **One-tap logging**: PEE / POOP buttons for the current litterbox, plus ACCIDENT buttons. Date and time are added automatically.
- **Multiple litterboxes**: add, rename, delete, and switch between labeled boxes. Renaming also relabels past entries.
- **Optional detail**: after logging, tag the entry (small/normal/large/blood for pee; normal/soft/hard/diarrhea/blood for poop) or add a free-text note. Skip it with one tap.
- **Edit previous entries**: change the date/time, pee/poop, place, detail or note, or delete an entry. The log re-sorts chronologically.
- **Reports**: recent history, plus a seven-day summary with per-day counts, accidents, and counts per litterbox.
- **Plain CSV storage**: easy to open in a spreadsheet or share with a vet.
- **E-ink friendly**: large buttons, no animations, no scrolling on the main screen.

## Requirements

- A device running KOReader (tested target: jailbroken Kindle Paperwhite 7th gen)
- No extra dependencies

## Installation

1. Download `catlog.koplugin.zip` from the [Releases](../../releases) page (or run `scripts/package.sh` yourself).
2. Unzip it so the folder `catlog.koplugin` ends up in KOReader's plugins directory. On a Kindle that is `koreader/plugins/catlog.koplugin/` on the USB drive.
3. Eject the device and restart KOReader.
4. Open the top menu, go to **Tools** (wrench icon), and choose **Cat continence log**.

**Tip:** bind "Cat continence log" to a gesture (for example a corner tap) in KOReader's gesture settings to open it from anywhere.

## Usage

| Button | What it does |
|---|---|
| PEE / POOP: *box* | Logs an event in the current litterbox |
| ACCIDENT: pee / poop | Logs an event outside the litterbox |
| Switch litterbox | Changes which box the PEE/POOP buttons use |
| History | Shows the last 40 entries |
| Weekly summary | Daily counts and per-place totals for the last 7 logged days |
| Edit entries | Scrollable list; tap an entry to edit or delete it |
| Undo last | Deletes the most recent entry |
| Manage litterboxes | Add, rename, delete, or choose the current box |

A new install starts with one litterbox called "Box 1". Rename it first under **Manage litterboxes**.

## Data

| File | Location (Kindle) | Contents |
|---|---|---|
| `catlog.csv` | `koreader/catlog.csv` | The event log |
| `catlog.lua` | `koreader/settings/catlog.lua` | Litterbox list and current box |

CSV columns: `datetime,event,place,detail,note`. `place` is a litterbox label or `accident`. See [`examples/catlog-sample.csv`](examples/catlog-sample.csv).

Back up both files if you reinstall KOReader. Commas and line breaks in notes and labels are replaced with spaces so the CSV stays valid.

## Troubleshooting

- **Menu entry missing:** check that the folder is named `catlog.koplugin` and contains `_meta.lua` and `main.lua`, then restart KOReader.
- **Errors or a blank screen:** include the relevant lines from `koreader/crash.log` in a bug report.
- **Wrong timestamps:** the Kindle's clock is used. Use **Edit entries → Date / time** to correct past entries.

## Roadmap ideas

- Export a summary as a printable page for vet visits
- Per-cat support
- Optional reminders

## Disclaimer

This is a logging tool only. It is not medical or veterinary advice. Talk to your vet about any health concerns.

## Contributing

Issues and pull requests are welcome. See `.github/ISSUE_TEMPLATE/` for the bug report template.

## License

MIT. See [LICENSE](LICENSE).
