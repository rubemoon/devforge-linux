# DevForge Linux

![DevForge Linux - full-stack developer workstation bootstrap](pro.png)

## Fedora setup

Extract the project, open its directory, and install the command:

```bash
bash install.sh
```

Preview the complete stack, then install it:

```bash
~/.local/bin/devforge install fullstack --dry-run --yes
~/.local/bin/devforge install fullstack --yes
```

The `fullstack` preset installs Git and build tools, Ruby and Rails, Node.js LTS, Python, Rust, PostgreSQL, Podman, and the Flutter Linux SDK. It uses asdf for Ruby, Node.js, and Python versions by default.

Restart the terminal when installation finishes, then check the environment with `~/.local/bin/devforge doctor`.

Android Studio, the Android SDK, JDK, and emulator are separate Flutter setup. PostgreSQL is installed but not initialized or started automatically.

Do not run DevForge with `sudo`. It uses sudo only when the system package manager needs it. `--dry-run` previews actions but does not download tools or resolve every remote version.

## Other commands

```bash
devforge list
devforge menu
devforge doctor
devforge install essentials,ruby,rails,node,python,flutter
bash tests/run.sh
```

Project lockfiles and version files remain unchanged. Choose versions per project when required.

## License

MIT. See [LICENSE](LICENSE).
