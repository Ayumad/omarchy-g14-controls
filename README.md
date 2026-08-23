# G14 Controls for Omarchy

Native Omarchy bar controls for ASUS ROG Zephyrus G14 laptops using the
supported `asusctl`/`asusd` stack. The bar widget shows the active power
profile, graphics mode, NVIDIA runtime state, and keyboard backlight level.
Click it (or press the configured ROG key) to open a Quickshell panel.

## Features

- Quiet, Balanced, and Performance profiles
- Keyboard backlight off/low/medium/high and next/previous effect
- Aura next, red, and blue effects
- Slash LED on/off
- Integrated, Hybrid, and Ultimate graphics modes
- Optional airplane-mode toggle through `rfkill`

Graphics mode changes are deliberately manual and require a reboot. The
plugin never switches graphics mode automatically and refuses to schedule a
change while NVIDIA compute processes are active.

## Requirements

- Omarchy Quattro and its Quickshell shell
- `asusd` running with `asusctl` available on `PATH`
- `jq` for status serialization
- ASUS WMI support for the controls exposed by the specific laptop

The bundled `g14ctl` helper runs with the logged-in user's permissions and
does not call `sudo`. The plugin and helper are unsandboxed, as are Omarchy
shell plugins generally; review the code before installing it on another
machine.

## Install

```sh
omarchy plugin add https://github.com/<owner>/omarchy-g14-controls.git --enable
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

## Remove

```sh
omarchy plugin remove ayumad.g14-controls
```

If you created a custom Hyprland keybinding, remove that binding separately.

## License

MIT. See `LICENSE`.
