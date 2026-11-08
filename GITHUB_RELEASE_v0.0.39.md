# DayArk v0.0.39 — The Open Source Beginning 🌱

This is a special update for me. **DayArk is becoming open source.**

I started DayArk about two years ago as my own personal project. I built the things I needed—tasks, reminders, finances, records, media tools—and kept adding features whenever they seemed useful. I also used AI development tools along the way. The code is not perfect and the UI needs a lot of love, but DayArk has been genuinely useful to me.

People around me didn't really need an app like this. Maybe someone somewhere does. I'm publishing the source so you can see how it works, use it, help improve it, or just explore what a Flutter project can become.

I want DayArk to be a **free, local-first option**, with no subscription required to use the features I publish. I'm not against paid software; I just think we should be able to get more out of the devices we already own.

## What's changed

- **Opening the source:** Introducing the public-source project, README, contribution guide, roadmap and license.
- **Life Archive:** Keep track of people, relationships, memories, photos and meaningful life events. I started this because I sometimes forget people's names and want an easier way to remember the people around me.
- **Visual relationships:** Explore family and personal connections in interactive charts and link existing people instead of creating duplicates.
- **Media Studio connections:** Browse Life Archive albums and scanned documents together while keeping the original records where they belong.
- **Appearance:** Life Archive now follows the main app theme. DayArk already includes light/dark modes and five accent presets; I'd love help making the UI even better.
- **Under the hood:** Recent work includes secure LAN sync, encrypted backups, stability refinements and code cleanup.

*Some improvements above were developed after v0.0.38; others are broader capabilities now present in the current source. The final published build needs to be checked against this list before release.*

## Want to contribute?

I would especially appreciate **UI design, better themes, performance improvements, testing, and code cleanup**. Longer-term ideas include a local chatbot/AI assistant, LAN chat and file sharing, local calls, notes, alarms, secure passwords, PDF/media tools and radio. These are ideas, not features I'm claiming are already finished.

You can help however you like—even a small bug report matters. I believe people make life better by helping each other.

Maybe this GitHub page won't get many visitors. But if one person finds it useful, I'll be happy.

**Thanks for being here and thanks to anyone who contributes.**

— **@mujtabax18**

## Important before updating

- **Back up your existing DayArk data** and store the backup safely before upgrading.
- Do not uninstall an existing Android app before installing an update with the same package ID/signature.
- Devices using LAN sync may need a new pairing after security/protocol changes.
- Download binaries only from the official Releases page; verify any published SHA-256 digests.
- The full Flutter project has been prepared for publication; review the repository history for signing keys before pushing and verify platform builds before announcing the release.

**Release draft:** This copy is prepared for a GitHub **draft** release. Publish only once source, license, installer signatures, backups and actual test results have been verified. Use the automated builder in `scripts/release.py` or GitHub Actions; no binaries were compiled by the documentation preparer.
