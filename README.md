# Skills and factories

Claude Code skills, agents and factories I reuse across projects.

| Folder | What |
| --- | --- |
| [`ios-factory/`](ios-factory/) | Software factory for iOS apps: `/factory`, `/factory-init`, `/issues`, `/roadmap`, `/decide`, `/testflight`, `/docs`, plus a project wiki. See its README. |

## Using the iOS factory in an app

```bash
git clone <this repo> ~/projects/skills-and-factories
~/projects/skills-and-factories/ios-factory/install.sh ~/projects/my-app            # first time, then /factory-init
~/projects/skills-and-factories/ios-factory/install.sh --update ~/projects/my-app   # pull in factory improvements later
```

`--update` refreshes only factory-owned files (agents, skills, scripts,
dashboard, templates). An app's config, roadmap, decisions, issues, releases,
product brief and wiki are never touched.
