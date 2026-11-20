# Headless dev environment (VM)

Everything needed to build, test and run the app on a fresh **Ubuntu 24.04** VM with no
display, plus a throwaway Nextcloud server with the Cookbook app. Requires nested virtualization
(`/dev/kvm` present), passwordless or interactive `sudo`, ≥ 16 GB RAM recommended.

## Where this lives (git)

`devenv/` is committed **only on the `devenv` branch** of the fork and is never merged, so PRs
stay clean. On a working copy it sits on disk as untracked files, ignored via the local-only
`.git/info/exclude`. Feature branches start from `main` as usual.

- Bring the files back (fresh clone): `git checkout origin/devenv -- devenv/ && git reset -q -- devenv/ && echo 'devenv/' >> .git/info/exclude`
- Save changes to it: commit in a temporary worktree:
  `git worktree add /tmp/devenv-wt devenv && cp -r devenv/. /tmp/devenv-wt/devenv/ && git -C /tmp/devenv-wt commit -am "..." && git -C /tmp/devenv-wt push && git worktree remove /tmp/devenv-wt`

## Rebuild from scratch

```bash
git clone git@github.com:dpoetzsch/nextcloud-cookbook-android.git ~/nextcloud-cookbook-android
cd ~/nextcloud-cookbook-android
git checkout origin/devenv -- devenv/ && git reset -q -- devenv/ && echo 'devenv/' >> .git/info/exclude
./devenv/setup.sh            # JDK, Docker, Android SDK, emulator + AVD, ~/.bashrc, local.properties
# log out and back in once (activates the kvm + docker groups)
./devenv/nextcloud/up.sh     # Nextcloud + Cookbook app on :8080, seeds 3 recipes
./devenv/emulator.sh         # boots the headless emulator, waits until ready
./devenv/run-app.sh          # builds, installs and launches the debug app
```

The first Gradle build takes ~13 min (downloads the Gradle JDK 21 toolchain and all dependencies);
later builds take about a minute.

In the app, log in with **Manual sign in**:
server `http://10.0.2.2:8080`, user `admin`, password `admin`.
(`10.0.2.2` is the emulator's alias for the VM itself.)

## What `setup.sh` installs

| What | Where / version |
|---|---|
| OpenJDK 21 (headless) | apt — runs Gradle; Gradle downloads its own JetBrains JDK 21 daemon toolchain (`gradle/gradle-daemon-jvm.properties`) |
| Docker CE + compose plugin | Docker's official apt repo (Ubuntu's `docker.io`/`docker-compose-v2` conflict with it — don't mix) |
| Emulator runtime libs, imagemagick | apt |
| Android cmdline-tools | `~/Android/Sdk/cmdline-tools/latest` |
| SDK packages | `platform-tools`, `emulator`, `platforms;android-36`, `build-tools;36.0.0`, `build-tools;35.0.0`, `system-images;android-35;google_apis;x86_64` |
| AVD `cookbook` | Pixel 6 profile, 3 GB RAM, `~/.android/avd/cookbook.avd` |
| Groups | user added to `kvm` and `docker` |
| Shell | `ANDROID_HOME` + PATH appended to `~/.bashrc`; `local.properties` with `sdk.dir` |

## Daily commands

| Task | Command |
|---|---|
| Start emulator / stop it | `./devenv/emulator.sh` / `./devenv/emulator.sh stop` |
| Build + install + launch | `./devenv/run-app.sh` |
| Unit tests | `./gradlew testFullDebugUnitTest` |
| Instrumented tests (emulator running) | `./gradlew connectedFullDebugAndroidTest` |
| Style / lint | `./gradlew ktlintCheck lint` |
| Start Nextcloud / wipe it | `./devenv/nextcloud/up.sh` / `./devenv/nextcloud/up.sh reset` |
| Nextcloud CLI | `docker exec -u www-data nextcloud-dev php occ <cmd>` |
| Screenshot | `./devenv/ui.sh shot shot.png` |
| Tap by visible text | `./devenv/ui.sh tap "Manual sign in"` (`tap "Sign in" last` for the last match) |
| Type into focused field | `./devenv/ui.sh type "hello"` |
| List visible texts | `./devenv/ui.sh dump` |

The Nextcloud web UI is also handy: forward port **8080** in VS Code and open
<http://localhost:8080> on your machine (admin/admin).

## Seeing the app on your own computer (scrcpy)

The emulator has no window. [scrcpy](https://github.com/Genymobile/scrcpy) shows it on your
machine as a live, clickable window, using the VM's adb server through two forwarded ports.

**One-time, on your local machine:** install scrcpy, which bundles adb.
macOS: `brew install scrcpy android-platform-tools`; Windows: download the scrcpy zip from its
releases page; Linux: your package manager or the scrcpy release. Use a **recent** adb: an adb whose version
differs from the VM's (currently 1.0.41 / platform-tools 37) may kill the VM's adb server.

**Each time:**

1. Make sure the emulator runs in the VM: `./devenv/emulator.sh`, then check that `adb devices`
   in the VM shows `emulator-5554  device`.
2. **Before forwarding anything**, stop your own local adb server so it frees port 5037:
   `adb kill-server`. Do it in this order: once 5037 is forwarded, `adb kill-server` goes through
   the tunnel and kills the **VM's** adb server instead. Your local machine then sees no device.
   In that case, run `adb devices` in the VM to restart its server.
3. Forward the ports **5037** (adb) and **27183** (scrcpy video) from the VM to the same local
   port numbers, either:
   - **VS Code**: *Ports* panel → *Forward a Port* → `5037`, then `27183`. Check that the
     "Forwarded Address" column shows `localhost:5037` / `localhost:27183`. If VS Code picked other
     numbers, something local still uses the port.
   - **or plain SSH**: `ssh -N -L 5037:localhost:5037 -L 27183:localhost:27183 dev@<vm>`
4. Locally run:
   ```bash
   adb devices                  # should list emulator-5554 (that's the VM's emulator)
   scrcpy --force-adb-forward
   ```

Close the scrcpy window when done. Before plugging in a local phone with adb again, remove the
5037 forward.

**Alternative:** install the APK on a real phone. Right-click
`app/build/outputs/apk/full/debug/app-full-debug.apk` in VS Code → *Download*. A phone can't
reach the VM's `10.0.2.2`, so log in against a real Nextcloud instead (or forward 8080 and use your
computer's LAN IP).

## Gotchas

- **Groups not active yet?** Until you re-login, `docker`/`emulator` fail with permission errors.
  The scripts fall back to `sg docker -c …` / `sg kvm -c …` automatically.
- **Two launcher icons** in debug builds: one is LeakCanary. `run-app.sh` starts
  `core.presentation.MainActivity` explicitly.
- Emulator log: `/tmp/emulator-cookbook.log`. Animations are disabled on boot for stable UI tests.
- Nextcloud data lives in the Docker volume `nextcloud_nextcloud-data`; `up.sh reset` deletes it.
