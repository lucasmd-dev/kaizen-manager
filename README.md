# Kaizen Manager

macOS menu bar app to manage a Kaizen-style project stack with three services: a Spring Boot backend, an Ionic mobile app and an Angular tools frontend.

## Features

- Start / stop each project with a single click
- Switch Git branches per project directly from the menu bar
- `git fetch --prune` button to refresh remote branches
- Global Node.js version switcher via `sudo n`
- Global Java version switcher (updates `JAVA_HOME` in `.zshrc`)
- Launch at login toggle
- **Configurable project root** — pick your local folder on first launch or via *Change Folder…*

## Requirements

- macOS 13+
- Xcode Command Line Tools (`swiftc`)
- [n](https://github.com/tj/n) installed at `/opt/homebrew/bin/n`
- Java installed and discoverable by `/usr/libexec/java_home`

## Build & Run

```bash
cd KaizenManagerApp
make
open build/KaizenManager.app
```

## Project Structure

The app expects the root folder you select to contain three subdirectories:

```
<root>/
├── KS-Service/   # Spring Boot — mvn clean spring-boot:run
├── KS-Mob/       # Ionic — npm run ionic:serve
└── KS-Tools/     # Angular — npm start
```

On first launch an **NSOpenPanel** will ask you to select this root folder.  
You can change it at any time via **Change Folder…** in the menu.

## Notes

- The sudo password for switching the global Node version is kept in memory only and is never written to disk.
- Log files (`KS-Service.log`, etc.) are written inside each project's own directory.
