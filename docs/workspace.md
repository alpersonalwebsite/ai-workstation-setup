# Display and comfort

Window management, monitor arrangement, lighting, brightness and dark mode.
Optional, and independent of everything else here.

Part of the [AI Workstation](ai-workstation.md) setup notes.

## Window and display management

### [Rectangle](https://rectangleapp.com/)

```bash
brew install --cask rectangle
```

- **What it's for:** Snap and tile windows with keyboard shortcuts, which is
  what makes a very wide monitor usable.
- **Replaces/changes:** Replaces dragging windows by hand, and replaces macOS's
  built-in drag-to-edge tiling (disable the built-in one to avoid conflicts:
  System Settings > Desktop & Dock > Tiled windows).

On an ultrawide, the free version's thirds (`Ctrl-Opt-D` / `F` / `G`) give three
full-height columns. That is the ceiling for free Rectangle: its built-in
column splits stop at thirds, and its anchor-based custom sizes (center, edges,
corners) cannot place the in-between columns of a 4- or 5-column layout. For
more columns you need Rectangle Pro (below) or [Moom](https://manytricks.com/moom/).

#### Rectangle Pro: 4 or 5 equal full-height columns

```bash
brew install --cask rectangle-pro
```

Rectangle Pro ($9.99 one-time, 10-day trial) is a superset of the free
Rectangle. You can keep both installed, but run only one at a time, otherwise
they fight over the same hotkeys, so quit or remove the free app once your
settings are in Pro. It adds custom **Size and Position** entries. The key is
the **Custom origin** position type, which exposes explicit X/Y fields, so you
can place every column, not just left/center/right.

Create one entry per column (Settings > Custom Size and Position > `+` > New
Size/Position > Position: **Custom origin**). Values **≤ 1** are fractions of
the screen (`0.2` = 20%, `1.0` = 100%); values **> 1** are pixels; blank keeps
the current value.

Five equal full-height columns, `Y = 0`, `H = 1.0`, `W = 0.2`:

| Column | X | Shortcut |
|---|---|---|
| 1 | 0   | `Ctrl-Opt-1` |
| 2 | 0.2 | `Ctrl-Opt-2` |
| 3 | 0.4 | `Ctrl-Opt-3` |
| 4 | 0.6 | `Ctrl-Opt-4` |
| 5 | 0.8 | `Ctrl-Opt-5` |

For four columns, use `W = 0.25` and `X = 0 / 0.25 / 0.5 / 0.75` (bind to
`Ctrl-Opt-Shift-1..4` so both sets coexist). If a numeric shortcut will not
record, it collides with another binding, use the `Shift` variant.

To place windows, put them on the ultrawide, then press the column's shortcut.

**On "use as a snap target":** enabling it on a column also turns that column
into a drag zone, so dragging *any* window (a browser, say) will try to snap it
into a 20%-wide strip. If that is unwanted, either leave snap targets off and
drive the columns by keyboard only, or set Rectangle Pro to snap on drag only
while a modifier is held (Settings > Snapping). The keyboard shortcuts work
regardless.

#### Rows and grids

Rows work exactly like columns, you just vary `Y`/`H` instead of `X`/`W`. For a
quick two-stack, the built-in halves are enough: `Ctrl-Opt-Up` (top half) and
`Ctrl-Opt-Down` (bottom half). For anything else, use Custom Size and Position.

Four equal full-height-width rows, `X = 0`, `W = 1`, `H = 0.25`:

| Row | Y |
|---|---|
| 1 | 0 |
| 2 | 0.25 |
| 3 | 0.5 |
| 4 | 0.75 |

Because `X`, `Y`, `W`, `H` are independent, any grid cell is expressible, a 2x2
quadrant is `W = 0.5, H = 0.5` at the four `X`/`Y` corners; a wide log pane under
five columns is a full-width `Y = 0.5, H = 0.5` row plus the five-column set
above it. Each cell is its own entry with its own shortcut.

**Targeting a specific display.** A custom entry can either follow the focused
window's current display, or be pinned to one monitor via the **Destination
display** field. Pinning is handy for portrait side monitors: e.g. two entries
"Row 2" and "Row 3" pinned to the left monitor place two stacked terminals there
with one keystroke each, no need to move the window over first. Duplicate the set
per monitor if you want the same rows on each. The trade-off: a pinned entry is
tied to that display's identity, so unplugging or rearranging monitors can change
the ID and the entry may need recreating.

#### Example: a full multi-monitor keymap

One worked layout, an ultrawide flanked by two portrait monitors, with every
target as its own custom entry (assign the shortcuts on the entries in **Custom
Size and Position**, and leave the built-in size actions unbound so nothing is
double-bound):

| Target | Shortcuts |
|---|---|
| Ultrawide, 5 columns (left→right) | `Ctrl-Opt-1 … 5` |
| Left monitor, 4 rows (top→bottom) | `Ctrl-Opt-Q / A / Z / X` |
| Right monitor, 4 rows (top→bottom) | `Ctrl-Opt-P / ; / . / /` |

Mnemonic: left-hand keys drive the left monitor, right-hand keys the right, and
going down the keyboard goes down the screen. Columns and side rows are all
display-pinned, so one keystroke both moves the window to the right monitor and
sizes it.

### [Lunar](https://lunar.fyi/)

```bash
brew install --cask lunar
```

- **What it's for:** Control external monitor brightness (plus volume and
  contrast) from the keyboard, and sync brightness across every display from one
  source. macOS brightness keys do not drive most non-Apple external monitors on
  their own; Lunar uses DDC/CI to do it, and falls back to a software overlay
  where DDC is unavailable.
- **Replaces/changes:** Replaces reaching for the monitor's physical joystick,
  and gives you one brightness control for all displays at once.

Lunar is paid: a **$23 one-time Pro license** unlocks **Sync Mode**, the adaptive
modes, and **multi-monitor support**. The free tier does DDC brightness, sub-zero
dimming, and the brightness keys, capped at about 100 adjustments a day, but
syncing across displays is Pro-only, so a multi-display setup like this one needs
the license. It is open source (github.com/alin23/Lunar), so its Accessibility
usage is auditable, and it needs macOS 12 or later. Grant it System Settings >
Privacy & Security > Accessibility.

**Free alternative:** [MonitorControl](https://github.com/MonitorControl/MonitorControl)
(`brew install --cask monitorcontrol`) is free and open source and does the same
DDC brightness control, but its cross-display **brightness sync is flaky**,
especially after sleep or opening/closing the lid, and it has no adaptive
(ambient, location, or sensor) modes. If you only want per-monitor brightness on
the keyboard, it is a fine free pick. For one control that drives every display
together, Lunar is the better tool.

How well DDC works depends on the connection, and it is worth treating as
something to test rather than assume:

- **DisplayPort, or USB-C in DP Alt Mode:** usually works, but not always. DDC
  support varies by monitor, by cable, and sometimes by which input you use on
  the same monitor. If a display will not take brightness commands, try its other
  input before concluding the app is broken.
- **Through a DisplayLink dock:** does not work. DDC does not pass through, so
  monitors on a dock fall back to overlay dimming or need their physical buttons.

If DDC does not work for a given display, that is usually the monitor or the
link, not the app.

### [displayplacer](https://github.com/jakehilborn/displayplacer)

```bash
brew install displayplacer
```

- **What it's for:** Command-line tool to read and set display modes. Useful for
  confirming what resolution and refresh rate a monitor is actually running at,
  rather than what you assume it is.
- **Replaces/changes:** Nothing. It is a diagnostic tool.

Worth checking on a high-resolution ultrawide: if the display offers only 60 Hz
at full resolution, the cause is almost always the port or the cable, not the
monitor's capability.

- Prefer USB-C (DP Alt Mode) or DisplayPort over HDMI, and use a full-spec cable.
- USB-C is not automatically equivalent to DisplayPort. On many monitors the
  USB-C port shares its bandwidth with USB data and hub duties, which can cap it
  at 60 Hz at full resolution. On my 49" Samsung this is exactly what happens:
  USB-C tops out at 60 Hz and only the dedicated DisplayPort 1.4 input gives
  120 Hz. If USB-C caps out, try the DisplayPort input before assuming the panel
  or the cable is the problem.
- Check the monitor's on-screen menu too. Many have a USB-C bandwidth or
  "DisplayPort version" setting that has to be raised manually.
- Do not route a high-resolution, high-refresh panel through a USB 3.0
  DisplayLink dock. Keep it on a native port and put lower-resolution secondary
  monitors on the dock.

## Lighting and eye comfort

Long coding sessions on a big, bright panel strain the eyes mostly through
*contrast*: bright screen against a dark desk and a dark wall behind it. Two
lights fix both.

### BenQ ScreenBar Halo 2 (monitor light bar)

Clamps on the top edge, centered (the weighted clip sits fine on the flat middle
of a curved ultrawide). It has two independent lights plus an ambient sensor.

**Front (task) light** — lights the keyboard/desk, not the screen:

| Setting | Value |
|---|---|
| Auto-dim | **ON** (sensor holds ~500 lux so the desk tracks the room) |
| Color temp, day | 4000–4500K (neutral) |
| Color temp, evening | 2700–3500K (warm) |
| Favorites | Save a **day** and an **evening** preset |

Save a favorite: dial the light to the look you want, **long-press the favorite
button (~3s)** until the bar blinks, then single-press it to recall.

**Rear "Halo" (bias) light** — soft glow behind the monitor, ON but low
(~10–20%), color temp matched to the Govee so the whole back-of-monitor zone
reads as one tone.

**Calibration check:** the asymmetric optics keep light off the screen. Glance at
the panel; if you see a reflection or hotspot, tilt the beam further down onto
the desk.

### Govee strip (bias / ambient)

Mounted behind the VIVO acoustic panel as a wall wash, set neutral-white and low.
It and the Halo rear light are both bias sources, so **one leads and the other
stays minimal** (Govee as the wall wash here; Halo rear kept low), and both share
a color temperature so they don't clash.

### Screen brightness and blue light

The screen is the other half of the contrast problem. Two settings and one
schedule keep it easy on the eyes.

**Match brightness to the room.** An external monitor has no ambient sensor, so
it sits at one brightness all day. Bridge that with the built-in sensor: turn on
macOS **Automatically adjust brightness** for the laptop display, and run
[Lunar](#lunar) in **Sync Mode** with the built-in as the **sync source** and
every external as a **sync target**, so they all follow the laptop's ambient
sensor from one place. Turn on **sub-zero dimming** for the displays you drive
over DDC (dims below the panel's hardware floor for a dark room, and sidesteps
the PWM backlight flicker some panels show at low brightness). Lunar restores the
levels across restart and wake, so confirm they come back after a reboot. Rule of
thumb: a white page should look like paper under the room light, not a lightbulb.

**Sync Mode and a closed lid.** Lunar has a **clamshell mode detection** setting
(Advanced Settings) that switches Auto/Sync to Manual when the lid closes, which
normally stops this. If it is off, unavailable, or does not fire, Sync stays
active in clamshell and can drag an external toward the now-absent built-in
source, writing a low brightness over DDC. The panel then looks dark with a
film-like cast and stays dark even after you quit Lunar, because the low value is
already written to the monitor. (A quick test to tell this apart from a live
software overlay: quit Lunar; if nothing changes, the darkness is a written
brightness value, not an overlay.) Fixes: check **Advanced Settings > clamshell
mode detection** first, and raise the external's brightness. Separately, some
monitors reset their own OSD brightness on the signal change a lid-close triggers;
if yours comes back dark, raise the OSD brightness and turn off the monitor's Eco
or auto-brightness so it stops reverting.

**Warm it in the evening.** Turn on macOS **Night Shift** and set the schedule to
**Sunset to Sunrise**, which enables it automatically each evening (the "Turn On
Until Sunrise" button is only a manual start-now and is not needed once the
schedule is set). Sunset to Sunrise needs **Location Services** on (specifically
the "Setting Time Zone" system service), because macOS computes local sunset and
sunrise from your location; if you keep Location Services off, use a **Custom**
schedule with fixed times instead. Set the color-temperature slider to moderate,
or a touch toward **More Warm**. Night Shift **may** apply to external displays
(support depends on the monitor, so check the result on that screen); use it *or*
the monitor's own low-blue-light mode, not both, or you double-warm. It shifts every
color on screen, so for color-sensitive evening work (photos, design) keep it
moderate or turn it off. For terminal and coding work, warmer is fine.

**In the monitor's OSD:** turn off whatever auto-adjusts contrast as content
changes (the brightness pumping is fatiguing). Its name varies by model: older
Samsungs have **Dynamic Contrast**, QLED/HDR ones like the ViewFinity S9 have
**Local Dimming** instead, so turn off whichever your menu actually shows. Keep
the input at its full refresh rate. The Eye Care menu also carries **Adaptive
Picture** (leave off: it auto-drives brightness and fights Lunar) and
**Eye Saver Mode** (leave off if you use Night Shift, or you double-warm).

**Keep one source of truth for brightness.** Drive it from Lunar, not the
monitor's buttons. Watch for the trap where a display looks dark but the app says
it is at full: that is almost always the monitor's own **OSD brightness set low,
even 0**, which the app cannot see past. Check the physical OSD brightness first
and set a sane baseline, then let Lunar be the day-to-day control. On a display
driven over DDC, Lunar sets the real backlight and its value is the authority; on
an overlay-only display Lunar just darkens on top, so the panel's own OSD
brightness still sets the ceiling. If the OSD and the app drift apart, reset the
OSD baseline, then nudge Lunar's slider once to write a fresh value.

**How Lunar controls each display (shown as its Control method):**

- **Apple native:** the built-in display (and any Apple external), driven by
  macOS directly. This is Lunar's ideal **sync source**, it carries the ambient
  sensor.
- **Hardware (DDC):** a monitor on a native connection that carries DDC/CI
  (DisplayPort, HDMI, or USB-C straight to the Mac, not through a DisplayLink
  dock). One exception: the built-in HDMI port on M1 Macs and the entry-level M2
  Mac mini carries no DDC even connected directly, so use USB-C or DisplayPort
  there. Lunar adjusts the real backlight, and **sub-zero dimming** extends the
  range below the panel's floor. This is what you want for the screen you look at
  most.
- **Overlay (software) dimming**, Lunar's fallback: when a display does not pass
  DDC (a DisplayLink dock monitor shows as a "virtual display," or DDC will not
  hold over a given hub or adapter), Lunar can only lay a dark overlay on top
  rather than lower the real backlight. It still dims and still syncs, but the
  backlight stays at full underneath, so prefer a native connection for real DDC
  control. If a display you know supports DDC lands on overlay, open its Lunar
  settings (the gear icon) and in **Controls** confirm **Hardware (DDC)** is
  checked; if it still falls back, enable **Try to enforce DDC** and move the
  slider to confirm the real backlight changes. That enforce toggle is what pulls
  a monitor on a hub or adapter onto DDC (it took both of my hub-connected Dells
  off overlay onto hardware control). If enforcing glitches or reverts, uncheck it
  and keep the overlay.

### Terminal colors

A terminal fills the screen, so its palette is most of what your eyes see all
day. Aim for a soft dark theme, not maximum contrast. The setting names below are
iTerm2's; other terminals have equivalents.

- **Off-black background, off-white text**, not pure `#000000` on `#ffffff`.
  Around `#15191f` background with `#dcdcdc` foreground is comfortable. Pure white
  on pure black is the harshest possible contrast and causes halation (text edges
  appearing to glow), worse with any astigmatism.
- **Bold heavier, not brighter.** Turn off **Brighten bold text** (older iTerm2
  labels it "Use bright version of ANSI colors for bold text") and do not set a
  pure-white custom bold color; let bold use the normal foreground so it reads as
  weight, not glare. Keep **Minimum Contrast** at 0 so nothing is forced harsher.
- **Opaque window**, no transparency or blur (text over anything but a solid
  color is harder to read), and a **steady, non-blinking cursor**.
- A legible monospace at a size you read without leaning in, with a little line
  spacing.
- **Apply the settings per profile and per appearance mode.** If you keep one
  profile per project, a tweak on a single profile does not propagate; each needs
  it. And with separate light/dark colors enabled, **Brighten Bold Text** and
  **Minimum Contrast** each have Dark and Light variants, so fixing it in Dark
  mode leaves Light mode untouched. Set it in both, or the glare survives where
  you did not look.

This pairs with the screen and lighting settings above: the terminal's dark
background is most of the screen's light output, so matching screen brightness to
the room is what keeps the whole picture comfortable.

### Dark mode across apps and the web

The terminal palette above is one app; the wider goal is to shrink the luminance
jump between a dark terminal or editor and a bright app, and to keep the screen
close to the room's brightness. Constantly swinging from near-black to white makes
your pupils re-adapt over and over. It is a comfort and fatigue question, not eye
damage, and matching polarity across apps reduces it.

- **macOS Dark mode** (System Settings > Appearance > Dark) flips native apps and
  the browser's own UI in one switch. The biggest consistency win for the least
  effort.
- **A browser's dark mode darkens the browser, not the page.** A site's content
  goes dark only if the site ships a dark theme and follows the OS
  `prefers-color-scheme` signal. Many (Gmail among them) stay white by default, so
  seeing white pages under system Dark mode is expected, not a bug.
- **Prefer each app's own dark theme, per app.** Where an app or site ships a
  dark theme, use that: macOS apps follow system Dark mode, and web apps set it
  themselves (Gmail: Settings > Theme > Dark, and so on). Native per-app themes
  render correctly and add no permissions, so this is the right default, and on a
  work machine it avoids granting an all-sites extension access to every page. For
  apps with no dark option, fall back to an extension like Dark Reader (per-site
  on and off) or Chrome's experimental `chrome://flags` Auto Dark Mode (force-darks
  every page, but often renders badly). Either way, leave reading-heavy pages
  light: long-form text is often more legible in light mode, and light on black
  can smear (halation), worse with astigmatism.
- **Keep the terminal a soft dark, not pure black** (see [Terminal
  colors](#terminal-colors)), so the jump to a light app is smaller to begin with.

The larger lever than polarity is still matching screen brightness to the room
(see [Screen brightness and blue light](#screen-brightness-and-blue-light)): a
white page strains most when the screen is much brighter than the space around it.
