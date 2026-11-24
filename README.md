# MaxGeneration: your life as a speed-run RPG (iPhone app)

A native SwiftUI iPhone app that turns your days into stages and your weeks into acts:

- **Daily run, ranked C → B → A → S → S+**: sleep, training, protein, calories, water, supplements, study and habits add up to a score. Tap **Finish day** for an arcade "DAY CLEAR!" results screen, where the score tallies up and your rank slams down.
- **Weekly check-in**: set your goals on Monday. On Sunday, log your weight, body fat %, how you felt and a **progress photo**, and get a WEEK CLEAR rank. Swipe through your photos to see your transformation.
- **Sleep first**: log bedtime and wake time (Galaxy Fit can't sync to iPhone apps, so it's a quick 2-tap entry).
- **Supplements**: Multivitamin, Omega-3, Creatine and Magnesium (night), each one a tap. Add your own in Settings.
- **Train**: gym workouts (exercise, sets, kg, reps, automatic PRs, 1RM charts) and boxing sessions (duration).
- **Food**: calories, protein and water cups, with targets you can adjust right in the Food tab.
- **Hero levels, 4 stats, daily quests, streaks, 28 achievements, boss battles** for big goals, and original arcade sound effects (toggle in Settings).

Everything stays private on your phone.

---

## Install it on your iPhone from a Windows PC (free)

You don't need a Mac. GitHub builds the app on its cloud Macs for free, and **Sideloadly** installs it from Windows using your normal Apple ID.

### 1. Let GitHub build the app (about 10 minutes, once)

1. Create a free account at **github.com**.
2. Click **+ → New repository**. Name it `MaxGeneration` and choose **Public**. Public repos get unlimited free build minutes; private repos only have a small monthly allowance. Then click **Create repository**.
3. On the new repo page, click **uploading an existing file**. Drag **everything inside** the `MaxGeneration` folder into the page: `MaxGeneration/`, `.github/`, `project.yml`, `README.md` and `.gitignore`. Then click **Commit changes**.
   - ⚠️ Make sure the `.github` folder was uploaded. If it's missing, click **Add file → Create new file**, type the name `.github/workflows/build.yml`, paste in the contents of that file, and commit.
4. Open the **Actions** tab. A run called **Build iPhone app** starts on its own. If it doesn't, click it and then **Run workflow**. Wait for the green ✓ (about 5 to 8 minutes).
5. Click the finished run, scroll to **Artifacts** and download **MaxGeneration-ipa**. Unzip it, and you'll have `MaxGeneration.ipa`.

### 2. Install it with Sideloadly

1. On your PC, install **iTunes** and **iCloud** from Apple's website. Use the versions from Apple's site, not the Microsoft Store versions, because Sideloadly needs Apple's drivers.
2. Install **Sideloadly** from sideloadly.io.
3. Plug your iPhone in with a cable, unlock it and tap **Trust**.
4. Open Sideloadly, drag `MaxGeneration.ipa` into it, enter your Apple ID email and click **Start**. Then enter your Apple ID password and any 2FA code when Sideloadly asks for them.
5. On the iPhone:
   - Go to **Settings → Privacy & Security → Developer Mode**, turn it on and restart. This is needed on iOS 16 and later.
   - Go to **Settings → General → VPN & Device Management**, tap your Apple ID and tap **Trust**.
6. Open **MaxGeneration** and create your hero 🎮

### The 7-day rule

Apps installed with a free Apple ID stop opening after **7 days**. To fix this, plug in your phone and click **Start** in Sideloadly again with the same `.ipa`. Reinstalling over the top **keeps all your data**. Sideloadly also has an auto-refresh option that can do this over Wi-Fi while your PC is on.

As a safety net, use **Hero → ⚙️ Settings → Export backup** now and then, and save the file to iCloud Drive.

> Free Apple IDs can have up to 3 sideloaded apps at once. A paid Apple Developer account ($99/year) removes the 7-day limit.

---

## Changing the app

All the code is in `MaxGeneration/`:

| File | What it does |
|---|---|
| `Models.swift` | Data types (workouts, foods, habits, bosses…) |
| `Store.swift` | Saving, XP rules, quests, PRs and streak logic |
| `Game.swift` | Level curve, rank titles, achievements, reminders |
| `Views/*.swift` | Each screen |

To change something, edit the file on GitHub (click it, then the ✏️ pencil) and commit. GitHub rebuilds the app automatically, and you install the new `.ipa` with Sideloadly. Your data stays.

Some easy tweaks:
- **XP amounts**: search for `award(` in `Store.swift`.
- **Level curve**: `xpToNext` in `Game.swift`.
- **Rank titles and colors**: `Leveling.title` in `Game.swift` and `Theme.rankColor` in `Views/Components.swift`.
- **New achievements**: add a line to `Achievement.all` in `Game.swift`.

If a build ever fails, open the failed run in **Actions** and copy the red error text. Paste it to Claude and it can fix it.
