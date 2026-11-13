# Testing a plugin revision in a local NOMAD Oasis

This guide describes how to run a local copy of `nomad-oasis-image` with a
specific commit or tag of a NOMAD plugin installed. It combines the repository's
local-testing instructions with the Windows fixes learned while testing the
`nomad-dtu-nanolab-plugin` feature from PR #282.

Everything in this guide runs on your own computer. It does not deploy to or
change the shared TEST Oasis at `http://10.40.23.94`.

> **Local testing only:** The example configuration uses HTTP and a local
> Docker socket. Do not use these settings on a shared or production Oasis.

## Purpose and safe operating rules

- **Goal:** build and run a local Oasis image whose plugin dependency is pinned
  to one known plugin commit or tag.
- **Run commands from:** the root of the `nomad-oasis-image` testing checkout.
- **Windows workflow:** use Windows PowerShell and Windows Git for repository
  and Docker commands. Use Git Bash or Ubuntu/WSL only to run the `.env`
  generator when needed.
- **Success check:** `curl.exe -i http://localhost/nomad-oasis/alive` returns
  HTTP 200, then the web UI and feature being tested work.
- **Protect data:** `.env` contains a secret. Never print or share it. Do not
  run `docker compose down -v` unless you intend to erase the Oasis database.
- **For automation/AI agents:** inspect the current branch and working tree
  before editing; make changes only in this local test checkout; do not push,
  deploy to the shared Oasis, or delete containers, volumes, or networks
  without explicit authorization. Do not paste full `docker compose config`
  output into logs or chat because it can include `.env` values.

## 1. Choose the plugin revision

You can pin either an immutable commit SHA or a tag in the plugin repository.
A full commit SHA is sufficient; creating a tag is optional. If you use a tag,
first create and push it from the plugin repository at the commit you want to
test, subject to your repository permissions.

Example tag commands for PR #282, run in a clone of the **plugin repository**.
Use the exact commit you intend to test; this example uses the PR commit above:

```powershell
git switch --detach acc5b1d1c04c47f973e202054dae8f6e16aaf687
git rev-parse HEAD
git tag -a test-pr-282-1 acc5b1d1c04c47f973e202054dae8f6e16aaf687 -m "Test plugin feature from PR 282"
git push origin test-pr-282-1
```

Confirm `git rev-parse HEAD` prints the intended SHA before tagging. Choose a
unique tag name. If you are testing a different commit, replace the example
SHA in both commands. If you cannot push a tag, pin the commit SHA directly in
the Oasis dependency instead.

For example, the feature commit used for PR #282 is:

```text
acc5b1d1c04c47f973e202054dae8f6e16aaf687
```

## 2. Prepare an Oasis testing branch

Use a separate branch in `nomad-oasis-image` so the test pin and any resulting
lockfile update are easy to identify:

```powershell
git clone https://github.com/DTU-Nanolab-materials-discovery/nomad-oasis-image.git
Set-Location nomad-oasis-image
git switch -c test-plugin-feature origin/main
```

If you already have a testing branch, fetch and switch to it instead:

```powershell
git fetch origin
git switch --track origin/combi-sample-testing
```

Edit the `nomad-dtu-nanolab-plugin` source in `pyproject.toml`. Use the actual
plugin repository URL and the commit SHA or tag—do not include any UI-rendered
repository-reference markup.

For a commit:

```toml
nomad-dtu-nanolab-plugin = { git = "https://github.com/DTU-Nanolab-materials-discovery/nomad-dtu-nanolab-plugin.git", rev = "acc5b1d1c04c47f973e202054dae8f6e16aaf687" }
```

For a tag, use its exact name as `rev`, for example:

```toml
nomad-dtu-nanolab-plugin = { git = "https://github.com/DTU-Nanolab-materials-discovery/nomad-dtu-nanolab-plugin.git", rev = "v0.4.19-test.282.1" }
```

Keep the inline table on one line, as shown. Then regenerate and inspect the
lockfile:

```powershell
uv lock
git status --short --branch
git diff -- pyproject.toml uv.lock
```

Confirm the `uv lock` output and `uv.lock` identify the intended plugin commit
or tag. `uv lock` may also update other dependency entries; review those changes
before keeping them. Commit the plugin pin and lockfile to the testing branch
if you want to preserve or share the exact test setup. The local Oasis
configuration changes below are machine-specific and should normally stay
uncommitted.

## 3. Prepare Docker and local data

Install and start Docker Desktop with its Linux/WSL 2 engine. Use **Windows
PowerShell and Windows Git consistently** for repository and Docker commands.
Avoid switching Git operations between Windows and WSL in a checkout under
`C:\`; the different Git and line-ending settings can make many files appear
modified.

From the repository root, verify Docker can reach both the client and server:

```powershell
docker version
```

Create the local file-system directories used by the Oasis:

```powershell
New-Item -ItemType Directory -Force -Path `
  '.volumes\fs\north\users', `
  '.volumes\fs\public', `
  '.volumes\fs\staging', `
  '.volumes\fs\tmp', `
  '.volumes\mongo' | Out-Null
```

The `chown` command in the Linux deployment instructions is not needed on
Windows.

## 4. Normalize the shell scripts and create `.env`

The original local-testing document normalizes four shell scripts to LF line
endings because shell scripts with Windows CRLF endings can fail inside Linux
containers. This PowerShell command edits the files as bytes, avoiding text
encoding changes:

```powershell
$files = @(
    'scripts\_setup_temporal.sh',
    'scripts\create-volumes.sh',
    'scripts\generate-env.sh',
    'scripts\backup-mongo.sh'
)
foreach ($file in $files) {
    $path = [System.IO.Path]::GetFullPath($file)
    $bytes = [System.IO.File]::ReadAllBytes($path)
    $normalized = [System.Collections.Generic.List[byte]]::new()
    for ($i = 0; $i -lt $bytes.Length; $i++) {
        if ($bytes[$i] -eq 13 -and $i + 1 -lt $bytes.Length -and $bytes[$i + 1] -eq 10) {
            continue
        }
        $normalized.Add($bytes[$i])
    }
    [System.IO.File]::WriteAllBytes($path, $normalized.ToArray())
}
```

The file changes shown by Git after this step may be line-ending-only. Do not
commit those local line-ending changes.

Create `.env` with the script from Git Bash or Ubuntu/WSL, started in the
repository root:

```bash
bash scripts/generate-env.sh
```

It creates a random 64-character API secret. If `.env` already exists, follow
the prompt rather than overwriting a secret you need. Keep `.env` private and
never commit it. Docker commands can still be run from Windows PowerShell; WSL
integration with Docker Desktop is only needed if you also want to invoke
`docker` inside Ubuntu.

## 5. Configure this checkout for local HTTP

Make these edits in the repository files—not in an attached copy or a separate
download.

In `configs/nomad.yaml`, change the local URLs:

```yaml
services:
  api_host: "localhost"
  api_base_path: "/nomad-oasis"
  # Keep the other existing services settings.

client:
  url: http://localhost/nomad-oasis/api

meta:
  deployment: "oasis"
  deployment_url: http://localhost/nomad-oasis/api
```

In `docker-compose.yaml`, under `services.proxy.volumes`, use the HTTP config
and disable the production HTTPS config and certificate mounts:

```yaml
    volumes:
      - ./configs/nginx_base_conf:/etc/nginx/conf.d/nginx_base_conf:ro
      - ./configs/nginx_http.conf:/etc/nginx/conf.d/default.conf:ro
      # Local testing does not use the production TLS certificate.
      # - ./configs/nginx_https.conf:/etc/nginx/conf.d/default.conf:ro
      # - /etc/ssl/certs/nomad_nanolab_dtu_dk_full.pem:/etc/nginx/tls/mounted-nomad-oasis.pem:ro
      # - /etc/ssl/private/nomad_nanolab_dtu_dk.key:/etc/nginx/tls/mounted-nomad-oasis.key:ro
```

The machine-specific `localhost` URLs are for the local copy only. Do not
apply them to the shared TEST Oasis.

## 6. Add local image-build overrides

Create `docker-compose.override.yml` in the repository root. It tells Compose
to build local images for the Oasis services rather than use their published
images. The base Compose file enables `cpu_worker`, so include it too:

```yaml
services:
  app:
    image: !reset null
    build:
      context: .
      target: final
  worker:
    image: !reset null
    build:
      context: .
      target: final
  north:
    image: !reset null
    build:
      context: .
      target: final
  cpu_worker:
    image: !reset null
    build:
      context: .
      target: cpu_action_final
  jupyterlab_image:
    image: ghcr.io/dtu-nanolab-materials-discovery/nomad-oasis-image/jupyter:main
    pull_policy: never
    build:
      context: .
      target: jupyter
```

The `jupyterlab_image` entry matters if notebooks must import the plugin
version under test. NORTH launches notebooks from the Jupyter image named in
`configs/nomad.yaml`, which by default is pulled from the registry (`:main`,
with the released plugin). Building the `jupyter` target locally under the same
tag, and setting `pull_policy: never`, makes NORTH use your build.

This `!reset` syntax requires a current Docker Compose version. Validate the
merged configuration before building:

```powershell
docker compose config --quiet
```

## 7. Build the images and start the Oasis

Avoid starting several image builds at once, especially on a computer with
limited memory. Build each service separately, waiting for it to finish:

```powershell
$env:COMPOSE_PARALLEL_LIMIT = '1'
docker compose build app
docker compose build worker
docker compose build north
docker compose build cpu_worker
docker compose build jupyterlab_image
```

Do not add `--parallel 1` to `docker compose build`; on the Compose version used
in this test it was parsed as a service name.

Once all five builds succeed, start the stack:

```powershell
docker compose up -d --no-build
docker compose ps
```

Compose may pull infrastructure images such as MongoDB, Postgres, Elasticsearch,
Temporal, and the Jupyter image. That is expected; `--no-build` prevents it from
rebuilding the local Oasis images. Do not run `docker compose pull` before the
local build.

Check the local HTTP endpoint and open the UI:

```powershell
curl.exe -i http://localhost/nomad-oasis/alive
```

The expected response is HTTP 200 with `"I am, alive!"`. Open
<http://localhost/nomad-oasis> in a browser, sign in if prompted, and try an
upload or analysis that exercises the plugin feature.

## Pause, restart, or shut down the local Oasis

Run these commands from the same repository root and with the same Compose
files and `.env` that were used to start the Oasis.

**Pause temporarily** while keeping the containers and data:

```powershell
docker compose stop
```

Resume the stopped services later:

```powershell
docker compose start
docker compose ps
```

**Shut down the stack** and remove its containers and Compose-created network,
while retaining named database volumes and the `.volumes` directory:

```powershell
docker compose down
```

Start it again later with the existing local builds:

```powershell
docker compose up -d --no-build
```

`docker compose down` does not remove the named database volumes or local
`.volumes` files. The local images remain available too. A separately renamed
container from another Compose project is not managed by this stack and will
remain stopped under its renamed name.

> **Destructive command:** Do not add `-v` to `docker compose down` unless you
> intentionally want to delete the named database volumes and their data. Do
> not remove `.volumes` unless you intentionally want to delete local files.

## Troubleshooting

### Docker engine stops or reports EOF during pull/build

Errors such as `unexpected EOF`, `failed to receive status`, or a 500 error
from `dockerDesktopLinuxEngine` indicate that Docker Desktop's engine stopped
responding. Wait for Docker Desktop to report that the engine is running, then
check:

```powershell
docker version
docker info
```

If builds repeatedly restart Docker Desktop, check available disk space and
Docker Desktop memory. Build one service at a time as shown above. Let each
command finish before entering the next one.

### Compose says `no such service: 1`

The command `docker compose build --parallel 1 app` is not valid for the
Compose version used here. Compose interpreted `1` as a service. Run
`docker compose build app` by itself instead. To limit Compose parallelism for
other operations, set `$env:COMPOSE_PARALLEL_LIMIT = '1'` in PowerShell.

### Docker cannot read a context `meta.json`

If Docker says it cannot read a file under
`%USERPROFILE%.docker\contexts\meta` because another process is using it,
wait for other Docker operations to finish and restart Docker Desktop. Do not
delete or edit the context metadata file.

### Build fails installing `kaleido==0.2.1`

One build failed with an invalid cached/downloaded Kaleido wheel
(`Metadata field Name not found`). A BuildKit cache prune was suggested but
was not verified as the fix. If this recurs, first retry the service build.
If the failure persists, `docker buildx prune` clears BuildKit's build cache
and can force a fresh download; it does not delete `.volumes`, but subsequent
builds will take longer. Review the command's prompt before confirming.

### `uv lock` updates more than the plugin

`uv lock` can refresh other unlocked dependencies as well as update the plugin.
Inspect `git diff -- uv.lock`. Confirm the plugin entry points at the selected
SHA or tag, and decide whether to keep any unrelated version updates. The
feature test succeeded with the plugin resolved as
`v0.4.19.dev12+gacc5b1d1c`.

### WSL cannot find Docker

If `docker` is unavailable inside Ubuntu, Docker Desktop's WSL integration
isn't enabled for that distribution. Either enable Ubuntu under Docker
Desktop's **Settings → Resources → WSL Integration** and apply/restart, or
leave Ubuntu and run Docker commands in Windows PowerShell. Docker does not
need to be installed separately inside Ubuntu for this workflow.

### Git reports dubious ownership or many files changed under WSL

When a Windows checkout under `/mnt/c` is accessed by WSL Git, Git may report
`dubious ownership`, and different line-ending settings can make many files
appear modified. Prefer Windows Git for all repository operations in a Windows
checkout. If this happens, inspect before restoring anything:

```bash
git diff --ignore-space-at-eol --stat
```

If the broad changes are only line endings and you have no intentional edits
in those files, restore only the affected files. Do not use a broad restore if
it could discard work. Avoid `sed -i` on Windows-mounted files if it fails
while preserving permissions.

### Bash scripts have CRLF line endings or PowerShell shows `>>`

The `>>` prompt means PowerShell is waiting for the rest of a command, often
because a backtick or quote was copied incorrectly. Press Ctrl+C to cancel,
then run the commands again from the normal prompt. PowerShell uses a backtick
for line continuation, not a backslash. When normalizing script line endings,
use the byte-preserving PowerShell command in step 4; do not substitute the
literal text `"rn"` for a CRLF sequence.

### Proxy restarts with a certificate / PEM error

The proxy is still loading the HTTPS configuration or a production certificate
that is unavailable locally. Check the merged proxy mounts without printing
the full Compose configuration, which can contain values from `.env`:

```powershell
$config = docker compose config --format json | ConvertFrom-Json
$config.services.proxy.volumes | Select-Object source, target
```

It should list `configs/nginx_http.conf` as the `default.conf` mount and should
not list `nginx_https.conf` or either TLS certificate mount. After correcting
the `proxy.volumes` section in the repository's `docker-compose.yaml`, recreate
only the proxy and check it:

```powershell
docker compose up -d --force-recreate proxy
docker compose ps proxy
docker compose logs --tail 50 proxy
curl.exe -i http://localhost/nomad-oasis/alive
```

### HTTP returns 502 after app or NORTH containers are recreated

Nginx may have cached the previous container IP for an upstream service. The
app can be healthy and reachable from another container while nginx still tries
the old IP. Look for `connect() failed` in the proxy logs, then test the app
from inside the proxy:

```powershell
docker compose logs --tail 50 proxy
docker exec nomad_oasis_proxy wget -S -O- -T 5 http://app:8000/nomad-oasis/alive
```

If the proxy log shows a refused connection to an old app IP, but the direct
request to `app:8000` returns HTTP 200, recreate only the proxy so it reloads
the current service address:

```powershell
docker compose up -d --force-recreate proxy
curl.exe -i http://localhost/nomad-oasis/alive
```

Recreating the proxy does not rebuild the Oasis images or delete Oasis data.

### Container name conflict or existing Compose network warning

Compose services have fixed container names. If a name conflict occurs, first
identify the existing container and its project/service labels:

```powershell
docker ps -a --filter "name=nomad_oasis_north"
$labels = (docker inspect nomad_oasis_north | ConvertFrom-Json)[0].Config.Labels
$labels.'com.docker.compose.project'
$labels.'com.docker.compose.service'
```

Do not remove a container until you know which project owns it. If it belongs
to another project and is stopped, renaming that stopped container can free
the name without deleting it:

```powershell
docker rename nomad_oasis_north nomad_oasis_north_previous
```

A warning that the named network already exists under another project did not
prevent the local Oasis from starting in this test. Do not delete or adopt
another project's network without checking what uses it.

### NORTH/Jupyter spawn returns HTTP 500 with Docker `PermissionError`

NORTH needs access to `/var/run/docker.sock` to start a Jupyter container. In
the test setup, the NORTH process user could not access the mounted socket,
and logs showed `PermissionError(13, 'Permission denied')`. For a disposable,
single-user local Oasis only, add this to the existing `north` section in
`docker-compose.override.yml`:

```yaml
  north:
    user: "0:0"
```

Keep the existing NORTH build override alongside it. Then recreate NORTH:

```powershell
$config = docker compose config --format json | ConvertFrom-Json
$config.services.north.user
$config.services.north.volumes | Select-Object source, target
docker compose up -d --force-recreate north
docker compose logs --tail 50 north
```

Running NORTH as root while it can access the Docker socket effectively gives
it control of the local Docker engine. Do not use this workaround on the
shared TEST Oasis or in production. The later message
`Only the nomad-service can launch specialized tools` followed the socket
failure in this test; diagnose the first Docker permission error first.

### Notebook cannot import new plugin classes (`ImportError: cannot import name ...`)

The Oasis app can have the plugin version under test while the NORTH notebook
does not. Notebooks run in a separate Jupyter image, by default pulled from
`ghcr.io/dtu-nanolab-materials-discovery/nomad-oasis-image/jupyter:main`, which
contains the released plugin. Classes added in the feature branch are then
missing from the notebook.

Confirm in a notebook cell:

```python
import importlib.metadata as m
print(m.version("nomad-dtu-nanolab-plugin"))
```

A tested version looks like `0.4.19.dev12+gacc5b1d1c`; a release number such as
`0.4.18` means the registry image is being used. Fix it by adding the
`jupyterlab_image` override from step 6, then:

```powershell
$env:COMPOSE_PARALLEL_LIMIT = '1'
docker compose build jupyterlab_image
docker compose up -d --no-build
docker compose up -d --force-recreate proxy
```

Then stop your running notebook server in the NORTH UI (**Control Panel /
Stop**) and launch a new one; an already running notebook keeps the old image.
Also check `docker image ls` shows a recently created
`.../jupyter:main`. Do not run `docker compose pull` afterwards: it would
replace your build with the registry image.

### `ArchiveQuery` returns 401, then `download()` returns `None`

Check that the notebook is querying the Oasis where the entry exists and that
the token is valid for that Oasis. A notebook running in the local Oasis but
using a production URL such as
`https://nomad.nanolab.dtu.dk/nomad-oasis/api` sends its available credentials
to production. A local Oasis token is not valid there, so the request can fail
with `401: Invalid token`. The later `NoneType` or indexing error is a
consequence of trying to use the failed download result; it is not the root
cause.

For a notebook running in a Jupyter container on the local Compose network,
query the local app service:

```python
from nomad.client import ArchiveQuery

analysis_id = "YOUR_LOCAL_ENTRY_ID"
a_query = ArchiveQuery(
    query={"entry_id:any": [analysis_id]},
    required="*",
    url="http://app:8000/nomad-oasis/api",
)
entry_list = a_query.download()
if not entry_list:
    raise RuntimeError(
        f"No entry was downloaded for {analysis_id}; check the URL, "
        "authentication, and whether this entry exists in the local Oasis."
    )
analysis = entry_list[0].data
```

Use an entry ID that exists in the local Oasis. An ID from production will not
necessarily exist locally; upload the relevant data to the local Oasis first.
If the notebook runs on the Windows host rather than in a Compose container,
use the local browser/API URL, `http://localhost/nomad-oasis/api`, instead of
`http://app:8000/...`.

If the analysis must be fetched from production, use a production-issued token
with the required access. Do not paste access tokens into notebooks committed
to Git, logs, or chat; provide them through a secure environment variable or
the approved secret-management method.

### A previously stopped NORTH container still owns the name

An existing stopped `nomad_oasis_north` container from another Compose project
prevented the new service from starting. Inspect its labels as above; if it is
stopped and owned by a different project, rename it rather than deleting it.
Never use `docker compose down -v` as a general troubleshooting step: `-v`
deletes named data volumes.

## Cleaning up

See [Pause, restart, or sh](#pause-restart-or-shut-down-the-local-oasis)curl.exe -i http://localhost/nomad-oasis/alive[ut down the local Oasis](#pause-restart-or-shut-down-the-local-oasis)
for the safe stop and restart commands. The HTTP, localhost, and NORTH
Docker-socket settings in this guide are for local development only. Testing
on the shared TEST Oasis requires coordination with its administrator and is
a separate deployment process.
