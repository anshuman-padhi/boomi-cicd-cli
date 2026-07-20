# Boomi‑XML SonarQube Test Environment (Podman, Apple Silicon)

A self‑contained test environment that runs **SonarQube Community** and a **self‑hosted
Azure DevOps agent** in Podman on an arm64 Mac, and an Azure pipeline that **exports
Boomi component XML (live)** and scans it against your custom **Boomi** quality profile
(`xml` language + `XPathCheck` rules).

```
┌──────────────────── podman machine (arm64 Linux VM) ─────────────────────┐
│  boomi-sonar-db (postgres:15)                                             │
│         ▲                                                                 │
│  boomi-sonarqube (sonarqube:community)  ── http://localhost:9001 (UI)     │
│         ▲  network: boomi-ci   http://boomi-sonarqube:9000 (internal)     │
│  boomi-azdo-agent (custom arm64)  ── runs getComponent.sh + sonar-scanner │
│         └────────────────────────────────────────────► dev.azure.com     │
└──────────────────────────────────────────────────────────────────────────┘
```

**Status:** Parts A–B and the agent image/scan path are **verified working on this
machine**. Parts C–F need your Azure DevOps + Boomi credentials.

> **Host port note:** host `:9000` was already in use on this machine, so SonarQube is
> published on **`:9001`** (container‑internal port is still `9000`, which is what the
> agent uses over the `boomi-ci` network).

---

## Prerequisites

- macOS on Apple Silicon, Podman with a running machine:
  ```bash
  podman machine list      # must show "Currently running"
  ```
- **One‑time VM tuning** (SonarQube's embedded Elasticsearch needs it; resets on VM reboot):
  ```bash
  podman machine ssh 'sudo sysctl -w vm.max_map_count=524288 fs.file-max=131072'
  ```
- **Behind a TLS‑intercepting proxy (Zscaler, etc.)?** In‑container HTTPS will fail unless
  the proxy's root CA is trusted. Export it into the (gitignored) agent build context:
  ```bash
  security find-certificate -a -c Zscaler -p /Library/Keychains/System.keychain \
    > test-env/agent/certs/zscaler.crt
  ```
  (Any `test-env/agent/certs/*.crt` is baked into the agent image. Skip if not behind a proxy.)

---

## Part A — Start SonarQube + Postgres  ✅ verified

```bash
podman compose -f test-env/podman-compose.yml up -d
# First boot takes ~2–4 min. Wait for UP:
until curl -fsS http://localhost:9001/api/system/status | grep -q '"status":"UP"'; do sleep 5; done
```

Open **http://localhost:9001** and log in as `admin` / `admin` (SonarQube forces a
password change on first UI login — remember the new password for Part B if you don't
use a token).

## Part B — Import the Boomi quality profile  ✅ verified

Imports the 11 XPath rules from `test-env/sonarqube/boomi-quality-profile.xml` and sets
the **Boomi** profile as default for the `xml` language.

```bash
# Using default admin creds (works before you change the password via API):
bash test-env/import-boomi-profile.sh
# Or with an admin token / changed password:
SONAR_ADMIN_TOKEN=squ_xxx bash test-env/import-boomi-profile.sh
```

Expected: `ruleSuccesses: 11, ruleFailures: 0`. Verify at
**http://localhost:9001/profiles?language=xml** → profile **Boomi** (11 active rules).

> The `bns:` namespace prefixes in the rules work as‑is — verified: a component named
> `New …` with non‑extensible connection fields produces 5 issues.

---

## Part C — Azure DevOps project, PAT, and agent pool  ⬜ you

1. **Project:** in https://anshumanpadhi.visualstudio.com → **New project** (e.g. `boomi-cicd`).
2. **Push this repo to Azure Repos** (the pipeline checks out `self`):
   ```bash
   git remote add azure https://anshumanpadhi.visualstudio.com/boomi-cicd/_git/boomi-cicd-cli
   git push -u azure test-env/sonarqube-boomi   # or your chosen branch
   ```
3. **Agent pool:** Project Settings → **Agent pools** → confirm/create a pool
   (default is `Default`; the pipeline's `pool.name` must match).
4. **PAT:** user menu → **Personal access tokens** → **New Token** →
   scope **Agent Pools (Read & manage)** → copy it.

## Part D — Build & run the self‑hosted agent  ⬜ you (image build ✅ verified)

```bash
cp test-env/.env.example test-env/.env
# edit test-env/.env: set AZP_URL=https://anshumanpadhi.visualstudio.com, AZP_TOKEN=<PAT>, AZP_POOL=Default
bash test-env/agent/run-agent.sh          # fetches sonar-scanner, builds arm64 image, registers + runs the agent
podman logs -f boomi-azdo-agent           # expect "Listening for Jobs"
```

Confirm the agent shows **Online** under Project Settings → Agent pools → your pool.
The agent image already bundles bash 5, jq, curl, xmllint, JRE 17 and sonar‑scanner, and
trusts your proxy CA.

## Part E — Variable groups & pipeline  ⬜ you

Pipelines → **Library** → create two variable groups:

| Group | Variable | Secret | Example |
|-------|----------|--------|---------|
| `boomicicd` | `authToken` | ✅ | `ACCOUNT.user:token` (NOT base64) |
| `boomicicd` | `baseURL` | ❌ | `https://api.boomi.com/api/rest/v1/ACCOUNT_ID/` |
| `boomi-sonar` | `sonarHostURL` | ❌ | `http://boomi-sonarqube:9000` |
| `boomi-sonar` | `sonarToken` | ✅ | analysis token (SonarQube → My Account → Security → Generate) |
| `boomi-sonar` | `sonarProjectKey` | ❌ | `Boomi` |

Create the pipeline: Pipelines → **New pipeline** → Azure Repos Git → your repo →
**Existing YAML** → `/ci-templates/azuredevops/pipelines/sonar_scan_boomi.yml`.

## Part F — Run the scan  ⬜ you

**Run pipeline** and set the `componentIds` parameter to one or more Boomi component IDs
(comma‑separated). Find IDs via the CLI or AtomSphere UI, e.g.:

```bash
cd cli/scripts
export authToken="ACCOUNT.user:token" baseURL="https://api.boomi.com/api/rest/v1/ACCOUNT_ID/" \
       SCRIPTS_HOME="$(pwd)" WORKSPACE="$(pwd)/workspace" \
       h1="Content-Type: application/json" h2="Accept: application/json" VERBOSE=false SLEEP_TIMER=0.2
source bin/queryProcess.sh processName="Your Process Name"   # prints componentId
```

The pipeline runs `sonar_scan_boomi.sh`, which does four things:
1. **Export** each component's XML with `getComponent.sh`.
2. **Extract** embedded Groovy/JS (`extract_scripts.sh`) from `<dataprocessscript>` bodies.
3. **Semgrep SAST** on the extracted scripts (`test-env/semgrep/boomi-scripts.yml`) → SARIF.
4. **SonarQube** scan: Boomi XPath profile on the XML + JS/secrets rules + Semgrep SARIF import.

Results appear at **http://localhost:9001/dashboard?id=Boomi**, and the extracted scripts +
`semgrep.sarif` are published as the **`boomi-scan`** pipeline artifact.

## Script security scanning (Groovy / JavaScript) with Semgrep

SonarQube Community does **not** do injection taint analysis (SQLi/XSS/XXE) and has no
Groovy analyzer, so the embedded scripts are scanned with **Semgrep** instead:

- `ci-templates/azuredevops/pipelines/extract_scripts.sh` — pulls each `<script>` body
  out of the component XML into `.groovy`/`.js` files (xmllint `string()` decodes the
  escaped source; extension from the `@language` attribute).
- `test-env/semgrep/boomi-scripts.yml` — a **local** ruleset (runs offline behind the
  proxy) covering hardcoded credentials, OS command injection, SQL-injection-by-concat,
  XXE (unhardened XML parsers), weak crypto, disabled TLS verification, and JS
  `eval`/`Function`. Groovy uses generic (token) rules; JS uses AST rules.
- Deeper coverage: add the registry when reachable —
  `semgrep --config test-env/semgrep/boomi-scripts.yml --config p/security-audit --config p/secrets`.
- **Gate the build**: set the pipeline's `semgrepFailOn` parameter to `error` or `warning`
  to fail on findings (default `none` = report only).
- `test-env/semgrep/samples/vulnerable.{groovy,js}` are deliberately-vulnerable fixtures
  (10 findings) to validate the ruleset.

> Semgrep runs with `--no-git-ignore` because the extracted scripts live under the
> git-ignored `workspace/` dir; without it Semgrep would scan "0 files tracked by git".

---

## How the SonarQube token is reused by the agent
The agent reaches SonarQube over the internal network at `http://boomi-sonarqube:9000`
(set `sonarHostURL` to exactly that). The browser uses `http://localhost:9001`.

## Corporate proxy (Zscaler) notes
- The scan itself talks to SonarQube over plain HTTP on the internal network — no proxy involved.
- Only the **agent registration** (to `dev.azure.com`) and **sonar‑scanner fetch** cross the
  proxy. The scanner zip is fetched on the host by `run-agent.sh`; the proxy root CA is baked
  into the image so agent registration validates. If registration still fails with a TLS error,
  re‑export the CA into `test-env/agent/certs/` and rebuild.

## Troubleshooting
| Symptom | Fix |
|---|---|
| SonarQube never reaches UP; logs mention `max virtual memory` / `vm.max_map_count` | Run the `podman machine ssh 'sudo sysctl -w vm.max_map_count=524288'` step. |
| `bind: address already in use` on 9000 | Already handled — host port is `9001`. Change in `podman-compose.yml` if 9001 is taken too. |
| Agent build fails with `SSL certificate problem` | Behind a TLS proxy — export the root CA into `test-env/agent/certs/` (see Prerequisites). |
| Agent registration TLS error to dev.azure.com | Same CA fix; rebuild the agent image. |
| `no valid component XML for <id>` in the scan | Wrong `componentId`, or `authToken`/`baseURL` invalid. Test `getComponent.sh` locally first. |
| Scan runs but 0 issues on a known‑bad component | Confirm the **Boomi** profile is the default for `xml`, or set `-Dsonar.profile`. |

## Teardown
```bash
podman compose -f test-env/podman-compose.yml down        # keep SonarQube data
podman compose -f test-env/podman-compose.yml down -v     # wipe data + volumes
podman rm -f boomi-azdo-agent                             # stop + unregister the agent
```

## Files
| Path | Purpose |
|---|---|
| `test-env/podman-compose.yml` | SonarQube + Postgres stack |
| `test-env/sonarqube/boomi-quality-profile.xml` | The 11 Boomi XPath rules (importable) |
| `test-env/import-boomi-profile.sh` | Restores the profile + sets default |
| `test-env/agent/Containerfile` + `start.sh` | arm64 Azure DevOps agent (bash5, jq, xmllint, JRE17, sonar‑scanner, Semgrep) |
| `test-env/agent/run-agent.sh` | Fetch scanner, build image, register + run agent |
| `test-env/.env.example` | Agent config template (copy to `.env`) |
| `ci-templates/azuredevops/pipelines/sonar_scan_boomi.yml` + `.sh` | The scan pipeline (export → extract → Semgrep → SonarQube) |
| `ci-templates/azuredevops/pipelines/extract_scripts.sh` | Extract embedded Groovy/JS from component XML |
| `test-env/semgrep/boomi-scripts.yml` | Semgrep ruleset for Boomi Groovy/JS (SQLi/XSS/XXE/creds/…) |
| `test-env/semgrep/samples/vulnerable.{groovy,js}` | Deliberately-vulnerable fixtures for validating the ruleset |
