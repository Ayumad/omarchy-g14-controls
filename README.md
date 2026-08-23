# G14 Controls for Omarchy

Native Omarchy bar controls for ASUS ROG Zephyrus G14 laptops using the
supported `asusctl`/`asusd` stack. It adds a compact Quickshell control panel
and three live bar glyphs for the G14, current power profile, and graphics
state. Click any glyph (or press the configured ROG key) to open the panel.

The bar and panel inherit Omarchy's active theme and font automatically. The
keyboard hue strip remains multicolored because it previews the actual Aura
color range rather than a UI theme color.

## Features

- **Live status glyphs** — focused tooltips show the current profile, detected
  dGPU model, graphics mode, and runtime state. An expansion-card glyph appears
  while the dGPU is active; the microchip glyph represents integrated or
  sleeping Hybrid states.
- **Power profiles** — Quiet, Balanced, and Performance controls. Adaptive
  configures ASUS defaults of Balanced on AC power and Quiet on battery; its
  bar glyph carries a small automatic badge while retaining the active profile
  symbol. Profile changes update the bar immediately and replace, rather than
  stack, their desktop notification.
- **Keyboard backlight and Aura** — Off/Low/Medium/High brightness controls,
  a horizontal hue-spectrum selector, and the modes actually exposed by the
  laptop firmware: Static, Breathing, Color Cycle, Rainbow, and Pulse.
- **Slash Lighting** — firmware-provided Slash modes, brightness levels, and
  explicit On/Off controls, shown in Advanced controls when supported.
- **Graphics/MUX controls** — Integrated, Hybrid, and Ultimate/dGPU modes.
  Changes are manual, require a reboot, and are blocked while NVIDIA compute
  processes are running.
- **Hardware-key ready** — the README includes the ROG-key binding; the panel
  also supports left-click to open, right-click to cycle profiles, and
  middle-click to refresh.
- **Theme-native UI** — the bar, ROG mark, panel, typography, and controls
  inherit the active Omarchy theme and font automatically. The keyboard hue
  strip stays multicolored because it is a lighting tool, not a theme accent.
- **Optional airplane mode** through `rfkill`.

The default panel is deliberately compact: profile, keyboard backlight, and a
visual keyboard-color slider are always visible. **Advanced controls** opens
one short section for Aura effects, Slash controls, and graphics mode.

Graphics mode changes are deliberately manual and require a reboot. The
plugin never switches graphics mode automatically, changes fan curves/TGP/CPU
limits, or requests privileged access. It uses the supported ASUS firmware
endpoints; unsupported model-specific features remain hidden rather than being
emulated.

## Requirements

- Omarchy Quattro and its Quickshell shell
- `asusd` running with `asusctl` and `rog-control-center` installed
- `jq` for status serialization and `pciutils` (`lspci`) for dGPU model detection
- ASUS WMI support for the controls exposed by the specific laptop

The bundled `g14ctl` helper runs with the logged-in user's permissions and
does not request administrative access. The plugin and helper are unsandboxed,
as are Omarchy shell plugins generally; review the code before installing it
on another machine.

## Install

```sh
omarchy plugin add https://github.com/Ayumad/omarchy-g14-controls.git --enable
omarchy bar move ayumad.g14-controls --section right
```

The default refresh interval is 10 seconds. It can be changed in the
widget's settings when supported by the shell.

## ROG-key binding

Add this to `~/.config/hypr/bindings.lua` if the laptop exposes the ROG key as
`XF86Launch1`:

```lua
hl.unbind("XF86Launch1")
o.bind("XF86Launch1", "G14 controls", "omarchy-shell shell toggle ayumad.g14-controls")
```

The widget's right-click cycles profiles and middle-click refreshes its state.
The included panel does not create or overwrite Hyprland keybindings; add only
the bindings you want.

## Remove

```sh
omarchy plugin remove ayumad.g14-controls
```

If you created a custom Hyprland keybinding, remove that binding separately.

## License

MIT. See `LICENSE`.
