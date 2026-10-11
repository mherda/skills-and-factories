# Skills and factories

Claude Code skills, agents and factories I reuse across projects.

| Folder | What |
| --- | --- |
| [`ios-factory/`](ios-factory/) | Software factory for iOS apps: `/factory`, `/factory-new`, `/factory-init`, `/issues`, `/roadmap`, `/decide`, `/design`, `/testflight`, `/docs`, plus a project wiki. See its README. |
| [`android-factory/`](android-factory/) | The same factory for Android apps (Kotlin, Compose, Gradle, one emulator per job): `/play` (Google Play internal testing) replaces `/testflight`. See its README. |
| [`mobile-factory/`](mobile-factory/) | Both in one, for a repo with an iOS app and an Android app (with or without shared code): one roadmap, decisions, inbox and wiki; checks cover every platform a change touches; `/testflight` and `/play`. See its README. |

## Using a factory in an app

Pick `ios-factory`, `android-factory` or `mobile-factory`; the commands are the same.

```bash
git clone <this repo> ~/projects/skills-and-factories
~/projects/skills-and-factories/ios-factory/install.sh ~/projects/my-app            # first time, then /factory-init
~/projects/skills-and-factories/ios-factory/install.sh ~/projects/new-app           # new app: creates + git-inits the folder, then /factory-new
~/projects/skills-and-factories/ios-factory/install.sh --update ~/projects/my-app   # pull in factory improvements later
```

Both commands also link the factory's git hooks (wiki checks). Hooks aren't
stored in git, so run `--update` once after cloning an app on a new machine.
`--update` refreshes only factory-owned files (agents, skills, scripts,
dashboard, templates). An app's config, roadmap, decisions, issues, releases,
product brief and wiki are never touched.

A repo uses one factory: they all install into `factory/` and
`.claude/skills/` under the same names. A repo with both apps uses
`mobile-factory`; `install.sh --update` from it moves a repo over from a
single-platform factory, keeping its trackers (see its README).
