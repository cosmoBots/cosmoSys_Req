# cosmoSys-Req

Requirements-domain extension for [cosmoSys](https://github.com/cosmoBots/cosmoSys),
a free and open source plugin for Redmine.

cosmoSys-Req adds requirements engineering capabilities to the cosmoSys base.
It lets a team capture, structure, trace and document requirements alongside
the rest of the project data, with live diagrams, DSM analysis, and
engineering-grade reports. It is free, open source, and has no per-seat limits.

cosmoSys provides the shared base; domain extensions such as cosmoSys-Req add
specialised capabilities on top of it.

## Project history

This is not a new project created by this repository. It is a refactoring and
continuation of the earlier
[`cosmosys_reqABANDONED`](https://github.com/cosmoBots/cosmosys_reqABANDONED)
and [`cosmosys_req_rm`](https://github.com/cosmoBots/cosmosys_req_rm) Redmine
plugins. That line of development runs from the first historical commit on 19
June 2019 through the current 2026 refactoring. The repository history was
deliberately restarted to publish a clean software artifact; this does not
erase or replace the project's earlier history and authorship.

## Status

This repository contains an early alpha artifact. It is suitable for controlled
evaluation and is not yet declared production-ready. You can install it and try
it, but expect breaking changes.

## Requirements

cosmoSys-Req requires the [cosmoSys](https://github.com/cosmoBots/cosmoSys)
plugin. Both are licensed under GPLv3 by cosmoBots.eu.

It is developed and validated against **Redmine 7.0.1** (Rails 8). It declares
`requires_redmine_plugin :cosmosys, version_or_higher: '0.1.1'`, so Redmine
refuses to start it unless the installed `cosmosys` version satisfies that
constraint. Earlier Redmine major versions are not supported.

## Installation (classic, no Docker)

cosmoSys-Req is installed into an existing Redmine instance the same way any
Redmine plugin is installed. You need a working cosmoSys installation first
(see its [README](https://github.com/cosmoBots/cosmoSys#installation-classic-no-docker));
this plugin adds the `requirement` profile and its trackers on top of the
cosmoSys base.

1. **Stop the web server** (or run migrations while no requests are served).

2. **Place the plugin in the plugins directory.** From the Redmine root, either
   clone the repository or copy the plugin files so that `plugins/cosmosys_req`
   exists:

   ```bash
   cd /path/to/redmine
   git clone https://github.com/cosmoBots/cosmoSys_Req.git plugins/cosmosys_req
   ```

   A packaged release can be unpacked to `plugins/cosmosys_req` instead. Only
   the plugin directory itself is required; cosmoSys-Req has no install-time
   dependency on this workspace.

3. **Install dependencies.** cosmoSys-Req declares no gems of its own; it
   consumes the cosmoSys runtime (which provides `libxml-ruby` and the pinned
   `rspreadsheet` revision) and Redmine's own gems. If cosmoSys was installed
   for the first time in this same step, run from the Redmine root:

   ```bash
   bundle install
   ```

   If you already installed cosmoSys earlier, no additional gems are needed
   for cosmoSys-Req.

4. **Run the plugin migrations.** cosmoSys-Req extends the Redmine schema with
   the requirement tables and columns. From the Redmine root:

   ```bash
   RAILS_ENV=production bundle exec rake redmine:plugins:migrate NAME=cosmosys_req
   ```

   For a development or test environment, set `RAILS_ENV=development` (or
   `test`) accordingly. Run the cosmoSys migrations first
   (`NAME=cosmosys`), then these; an upgrade from an earlier release migrates
   `001` through the latest sealed number (`001`–`004` for the current release
   line).

5. **Create the requirement profile and trackers.** cosmoSys-Req registers the
   `requirement` item profile and the `requirements` project profile with its
   structural trackers `csRq`, `csRqm`, `csRqr` and `csRqmr`. Assigning a
   Requirements project profile to a project sets up those trackers and the
   modules that profile requires. See the cosmoSys project creation flow: the
   first step selects a project profile, the second presents Redmine's normal
   project form with the profile's modules preselected. After migration, create
   a project and choose the **Requirements** profile (visible once
   cosmoSys-Req is loaded) to exercise the domain.

6. **Restart Redmine** so the plugin is loaded, then confirm cosmoSys-Req
   appears in the administration plugin list alongside cosmoSys.

### Upgrading an existing installation

To update cosmoSys-Req in place:

```bash
cd /path/to/redmine
git -C plugins/cosmosys_req fetch
git -C plugins/cosmosys_req checkout <new-tag-or-sha>
RAILS_ENV=production bundle exec rake redmine:plugins:migrate NAME=cosmosys_req
# restart Redmine
```

The migration base is developed fast and the project is still in alpha: the
schema is not yet backward-compatible by design, so back up the database
before upgrading. cosmoSys-Req also depends on the cosmoSys base, so upgrade
cosmoSys to the required version in the same maintenance window.

### Deployment with Docker Compose (optional)

If you prefer a packaged, reproducible deployment instead of installing into
an existing Redmine, the same sister project as cosmoSys provides a Docker
Compose stack with a variant that includes cosmoSys-Req (pinned plugin
revisions, health checks, backups and restore scripts). It is currently being
published at <https://github.com/cosmoBots/cosmoSys_deploy> and should be
available there shortly.

## Repository

The canonical repository for this project is
[github.com/cosmoBots/cosmoSys_Req](https://github.com/cosmoBots/cosmoSys_Req).
Forks and mirrors are welcome under the terms of the GPLv3, but they are not
maintained by cosmoBots.eu and may diverge from this source.

## Contact and licence

- Contact: txinto@elporis.com
- Licence: GNU General Public License version 3; see [`LICENSE`](LICENSE).
