# Kaizen Manager

macOS menu bar app to manage the Kaizen project stack (KS-Service, KS-Mob, KS-Tools).

## Features

- Start / stop each project with a single click
- Switch Git branches per project directly from the menu bar
- `git fetch --prune` button to refresh remote branches
- Global Node.js version switcher via `sudo n`
- Global Java version switcher (updates `JAVA_HOME` in `.zshrc`)
- Launch at login toggle

## Requirements

- macOS 13+
- Xcode Command Line Tools (`swiftc`)
- [n](https://github.com/tj/n) installed at `/opt/homebrew/bin/n`
- Java installed via `/usr/libexec/java_home`

## Build & Run

```bash
cd KaizenManagerApp
make
open build/KaizenManager.app
```

> **Note:** Edit the `projectPath` values in `AppDelegate.swift` to match your local Kaizen repository paths before building.
