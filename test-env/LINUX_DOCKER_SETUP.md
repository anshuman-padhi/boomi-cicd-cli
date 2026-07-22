# Boomi Component Scanning — Linux + Docker Setup (SonarQube Community + Semgrep)

Stand up the full demo on a **single Linux VM with Docker**: SonarQube Community (Boomi
XPath best-practice rules) and Semgrep (security SAST on embedded Groovy/JS), driven by an
Azure DevOps self-hosted agent. Everything runs in Docker on the one VM.

```
┌──────────────────────── Linux VM (Docker) ─────────────────────────────┐
│  boomi-sonar-db (postgres:15)                                           │
│        ▲                                                                │
│  boomi-sonarqube (sonarqube:community)  ── http://<VM>:9000 (UI)        │
│        ▲  docker network: boomi-ci   http://boomi-sonarqube:9000        │
│  boomi-azdo-agent  ── ADO agent + sonar-scanner + Semgrep + jq/xmllint  │
│        │  runs the pipeline:                                            │
│        │  export(Boomi API) → extract Groovy/JS → Semgrep → SonarQube   │
│        └────────────────────────────────────────────► dev.azure.com    │
└──────────────────────────────────────────────────────────────────────┘
```

**What each engine does**
- **SonarQube Community** — analyzes the component **XML** with the `xml` analyzer + the
  imported **Boomi** quality profile (11 XPath rules: naming, extensible creds, DLQ, …),
  plus secrets and JS quality. Persistent dashboard + quality gate.
- **Semgrep** — SAST on the **extracted Groovy/JS code**: SQLi, XSS, XXE, hardcoded creds,
  command/code injection, weak crypto, SSRF, etc. (the injection classes Community can't do).

---

## 1. Prerequisites

**VM**
- Linux (Ubuntu 22.04+ / RHEL 8+ / Amazon Linux 2023), **4 vCPU, 8 GB RAM, 30 GB disk**
  (SonarQube's Elasticsearch alone wants ~2–3 GB).
- **Docker Engine + Compose plugin** (`docker --version`, `docker compose version`).
- Outbound network access to:
  - `dev.azure.com` / `*.visualstudio.com` — agent registration + jobs
  - `api.boomi.com` (or your Boomi API base) — component export
  - `binaries.sonarsource.com`, `pypi.org`, `files.pythonhosted.org`, `docker.io` — image build
  - `semgrep.dev` — **only** if you enable registry rule packs (the bundled local ruleset is offline)

**Accounts / tokens**
- **Azure DevOps**: an organization + project, and a **PAT** with scope *Agent Pools (Read & manage)* (and *Code Read & write* if you push the repo to Azure Repos).
- **Boomi**: an API token (`ACCOUNT.username:token`), the API base URL, and the **component ID(s)** to scan.
- **SonarQube**: you'll generate an analysis token after first login (Step 4).

> **Behind a TLS-intercepting proxy (Zscaler etc.)?** Drop your root CA as
> `test-env/agent/certs/*.crt` before building the agent image — it's baked into the trust
> store so in-container HTTPS (agent download, pip, sonar-scanner fetch) works. Skip if not.

---

## 2. Prepare the VM

```bash
# Docker Engine + compose plugin (Ubuntu example)
curl -fsSL https://get.docker.com | sudo sh
sudo usermod -aG docker "$USER"   # re-login after this

# SonarQube/Elasticsearch kernel requirement (persist across reboots)
sudo sysctl -w vm.max_map_count=524288
echo "vm.max_map_count=524288" | sudo tee /etc/sysctl.d/99-sonarqube.conf

# Get the code onto the VM
git clone <your-boomi-cicd-cli-repo> && cd boomi-cicd-cli
```

---

## 3. Start SonarQube Community + Postgres

```bash
docker compose -f test-env/docker/docker-compose.yml up -d
# First boot ~2–4 min. Wait for UP:
until curl -fsS http://localhost:9000/api/system/status | grep -q '"status":"UP"'; do sleep 5; done
```

Open **http://\<VM\>:9000**, log in `admin` / `admin`, and set a new admin password when prompted.

---

## 4. Import the Boomi quality profile + create an analysis token

```bash
# Import the 11 Boomi XPath rules and set the profile default for xml
SONAR_URL=http://localhost:9000 SONAR_ADMIN_PASS='<new-admin-password>' \
  bash test-env/import-boomi-profile.sh
# Expected: ruleSuccesses: 11, ruleFailures: 0
```

Then in the UI: **avatar → My Account → Security → Generate Tokens** →
Name `azure-pipeline`, **Type = Global Analysis Token** → **Generate** → copy it (used as
the `sonarToken` variable in Step 6).

---

## 5. Build & run the Azure DevOps agent (with Semgrep + sonar-scanner)

The agent image bundles the ADO agent, `bash`/`jq`/`curl`/`xmllint`, JRE 17, `sonar-scanner`
and **Semgrep** — so the whole pipeline runs inside it.

```bash
# 5a. Fetch sonar-scanner on the VM (copied into the image; avoids in-container download quirks)
curl -fsSL "https://binaries.sonarsource.com/Distribution/sonar-scanner-cli/sonar-scanner-cli-5.0.1.3006.zip" \
  -o test-env/agent/sonar-scanner.zip

# 5b. Build the agent image (amd64 VM: no --platform needed; the Dockerfile is arch-agnostic)
docker build -f test-env/agent/Containerfile -t boomi-azdo-agent test-env/agent

# 5c. Run the agent on the same network as SonarQube
docker network create boomi-ci 2>/dev/null || true
docker run -d --name boomi-azdo-agent --restart unless-stopped \
  --network boomi-ci \
  -e AZP_URL="https://dev.azure.com/<your-org>" \
  -e AZP_TOKEN="<azure-devops-PAT>" \
  -e AZP_POOL="Default" \
  -e AZP_AGENT_NAME="boomi-linux-agent" \
  boomi-azdo-agent

docker logs -f boomi-azdo-agent      # expect "Listening for Jobs"
```

Confirm the agent shows **Online** under **Project Settings → Agent pools → Default**.

> Secrets note: pass `AZP_TOKEN` via an env file (`--env-file`) or your VM's secret store,
> not inline, in a real deployment.

---

## 6. Configure the Azure DevOps pipeline

1. **Repo** — push this repo to Azure Repos (or point the pipeline at your existing repo host).
2. **Variable groups** — Pipelines → **Library**:

   | Group | Variable | Secret | Value |
   |-------|----------|--------|-------|
   | `boomicicd` | `authToken` | ✅ | `ACCOUNT.username:token` (plain, not base64) |
   | `boomicicd` | `baseURL` | ❌ | `https://api.boomi.com/api/rest/v1/<ACCOUNT_ID>/` |
   | `boomi-sonar` | `sonarHostURL` | ❌ | `http://boomi-sonarqube:9000` |
   | `boomi-sonar` | `sonarToken` | ✅ | the Global Analysis Token from Step 4 |
   | `boomi-sonar` | `sonarProjectKey` | ❌ | `Boomi` |

   > **`sonarHostURL` = `http://boomi-sonarqube:9000`** because the agent and SonarQube share
   > the `boomi-ci` Docker network. (If you instead run the agent **natively** on the VM
   > rather than as a container, use `http://localhost:9000`.)

3. **Create the pipeline** — Pipelines → New pipeline → your repo → **Existing YAML** →
   `/ci-templates/azuredevops/pipelines/sonar_scan_boomi.yml`. Ensure `pool.name` matches
   your agent pool (`Default`).

---

## 7. Run the scan & where the reports are

**Run pipeline** → set parameters:
- `componentIds` — comma-separated Boomi component IDs to scan.
- `semgrepFailOn` — `none` (report only, default), or `error`/`warning` to **gate** the build.
- `semgrepExtraConfig` — optional registry packs, e.g. `p/security-audit p/secrets` (needs `semgrep.dev` access).

**Reports:**
- **SonarQube** → `http://<VM>:9000/dashboard?id=Boomi` — quality gate, Issues (XPath rule
  violations + imported Semgrep findings + secrets), Measures, history.
- **Pipeline step log** — the scan step prints the Semgrep summary (`[level] rule — file:line`).
- **Pipeline run → Artifacts → `boomi-scan`** — downloadable `semgrep.sarif`, the extracted
  `.groovy/.js`, and the component XML. (Install the free **"SARIF SAST Scans Tab"** ADO
  extension to render the SARIF as a tab.)

---

## 8. Operations & options

- **Enforce security in CI**: default the pipeline to `semgrepFailOn: error`.
- **Deeper Semgrep coverage**: `semgrepExtraConfig = p/security-audit p/secrets p/javascript`.
- **Update the agent** (e.g., new tooling): `docker rm -f boomi-azdo-agent` then rebuild + run (Step 5). The agent auto-unregisters on stop and re-registers with `--replace`.
- **Teardown**:
  ```bash
  docker rm -f boomi-azdo-agent
  docker compose -f test-env/docker/docker-compose.yml down       # keep SonarQube data
  docker compose -f test-env/docker/docker-compose.yml down -v    # wipe data + volumes
  ```
- **Hardening for anything beyond a demo**: don't expose SonarQube (:9000) publicly; put it
  behind TLS/reverse-proxy; use ADO secret variables (never plaintext) for `authToken`/
  `sonarToken`/PAT; restrict the `boomi-scan` artifact retention (it contains exported
  component XML + scripts).

### Alternative: native agent instead of a container
If you prefer the ADO agent installed natively on the VM (systemd service) rather than a
container: install the agent from *Project Settings → Agent pools → New agent (Linux)*, and
install the tooling on the VM — `jq curl libxml2-utils default-jre`, `sonar-scanner`, and
`pip install semgrep`. Keep SonarQube in Docker (Step 3). Set `sonarHostURL=http://localhost:9000`.
The pipeline YAML is unchanged.

---

## File map
| Path | Purpose |
|---|---|
| `test-env/docker/docker-compose.yml` | SonarQube Community + Postgres (port 9000) |
| `test-env/agent/Containerfile` + `start.sh` | Agent image (arch-agnostic: builds on amd64 & arm64) |
| `test-env/import-boomi-profile.sh` | Import the Boomi quality profile + set default |
| `test-env/sonarqube/boomi-quality-profile.xml` | The 11 Boomi XPath rules |
| `test-env/semgrep/boomi-scripts.yml` | Semgrep ruleset (17 rules) for Groovy/JS |
| `ci-templates/azuredevops/pipelines/sonar_scan_boomi.yml` + `.sh` | The scan pipeline |
| `ci-templates/azuredevops/pipelines/extract_scripts.sh` | Extract embedded Groovy/JS from component XML |
