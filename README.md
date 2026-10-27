# CADMUS-CR-14 · Secure Coding Java — sandbox definition

Sandbox definition for the CyberRangeᶜᶻ platform (cr.cybersec.upatras.gr) used by
the CADMUS bootcamp **BTCMP-02 Secure Coding**, Cyber Range course
**CADMUS-CR-14 Secure Coding Java**.

It implements section 2 *Training Scenario Architecture* of the
*CADMUS Cyber Range Training Scenario Framework* for CR-14: a Windows 11
developer workstation plus two Docker hosts carrying the SAST and DAST tools.
The application under test is
[`aradovanJava/cadmus-vulnshop-cr`](https://github.com/aradovanJava/cadmus-vulnshop-cr),
a deliberately vulnerable Spring Boot 4 / Java 25 storefront.

> **Training system.** The application under test contains a working remote
> code execution path. It is meant to run only inside this sandbox. See
> `SAFETY.md` in the application repository.

## Topology

```
                 internet-connection (WAN)
                           |
                        router  10.10.10.1
                           |
   dev-lan 10.10.10.0/24 --+-----------------------+----------------------+
                           |                       |                      |
                 sc1  10.10.10.10         sq1  10.10.10.20        owz1  10.10.10.30
                 VM1  Windows 11          VM3  SonarQube          VM2  OWASP ZAP
                 trainee workstation      (Docker, SAST)          (Docker, DAST)
```

| Host | Framework ID | Image | Flavor | Role |
|---|---|---|---|---|
| `sc1` | VM1 · SC1 | `windows-11-bkp-x86_64` | `c4_r8_d60` | Developer workstation, RDP access |
| `sq1` | VM3 · SQ1 | `ubuntu-noble-x86_64` | `c4_r8_d40` | SonarQube Community Build in Docker |
| `owz1` | VM2 · OWZ1 | `ubuntu-noble-x86_64` | `c2_r4_d40` | OWASP ZAP in Docker (desktop UI via Webswing) |
| `router` | — | `debian-12-x86_64` | `standard.small` | Gateway |

### Software on SC1 (framework table 2.1, VM1)

Oracle JDK 25 (`JAVA_HOME` set), Git, Apache Maven, Node.js LTS, Python 3,
SQLMap, Snyk CLI, IntelliJ IDEA Ultimate, Postman. The application is cloned
to `C:\Lab\cadmus-vulnshop-cr`; a README and browser shortcuts are placed on
the desktop and an environment check at `C:\Lab\verify-cr-env.ps1`.

## Access

| | |
|---|---|
| Account on all three machines | `user` / `Password123` — the platform's standard sandbox account (administrator on SC1 with RDP, sudo + docker on SQ1/OWZ1) |
| SonarQube | `http://localhost:9000` on SC1 (forwarded to SQ1); first login `admin` / `admin`, then a forced password change |
| OWASP ZAP desktop | `http://owz1:8080/zap/` from SC1; proxy/API on `owz1:8090` |
| Application from SC1 | `http://127.0.0.1:8080/shop` after `tools\run-app.ps1` |
| Application as ZAP sees it | `http://sc1:8080/shop` |

Credentials and every other tunable are in `provisioning/group_vars/all.yml`.

## Design decisions

1. **SQ1 and OWZ1 run Ubuntu 24.04, not Windows 11.** Table 2.1 lists Windows 11
   for the two Docker hosts. Docker on Windows needs WSL 2 / Hyper-V, i.e.
   nested virtualisation, which OpenStack sandboxes generally do not offer.
   The tools, ports and roles are exactly those of the framework; only the
   host OS of the two containers differs.
2. **The application stays bound to `127.0.0.1`,** as `SAFETY.md` requires.
   Because the framework puts ZAP on a separate machine, SC1 forwards
   `10.10.10.10:8080` to `127.0.0.1:8080` (`netsh interface portproxy`) and a
   Windows Firewall rule admits that port from OWZ1 (`10.10.10.30`) only.
3. **SonarQube is reachable as `http://localhost:9000` on SC1** through a second
   port forward, so `tools\scan-sonar.ps1`, `sonar-project.properties` and the
   CR1 lab guide work without edits. `tools\verify-env.ps1` will still report
   *docker MISSING* on SC1 — expected here; trainees use
   `C:\Lab\verify-cr-env.ps1`.
4. **Tools are started for the trainee by default** (`cr14_autostart_tools: true`).
   Set it to `false` if levels A1/A3 should include starting them: images are
   then pre-pulled and containers created but not started, and the trainee
   runs `ssh user@owz1` / `ssh user@sq1`, `cd /opt/cr14 && docker compose up -d`.
5. **SonarQube is pulled from the ECR Public mirror of the Docker Official
   Image first**, falling back to Docker Hub, because a pool of sandboxes
   pulling anonymously from Docker Hub runs into its rate limit.
6. **Level E1 (GitHub Actions)** runs on GitHub, outside the sandbox. Trainees
   fork `cadmus-vulnshop-cr` to their own account and complete
   `.github/workflows/security-pipeline.yml` in the fork.

## Mapping to the training levels

| Level | Machine(s) | What the sandbox provides |
|---|---|---|
| 0 · Access | SC1 | RDP account, desktop README, environment check |
| A1/A2 · DAST | SC1 → OWZ1 → SC1 | ZAP desktop at `owz1:8080/zap/`, target `http://sc1:8080` |
| A3/A4 · SAST | SC1 → SQ1 | SonarQube at `localhost:9000`, Maven scanner, Snyk |
| C1/C2 · Research and fixes | SC1 | IntelliJ IDEA, source in `C:\Lab\cadmus-vulnshop-cr` |
| D1 · Patch and redeploy | SC1 | Git, Maven, local run and rescan |
| E1 · CI/CD | GitHub | Trainee's fork with the starter workflow |

## Using it on the platform

1. **Sandboxes → Definition → Create**
   Git URL `https://github.com/aradovanJava/cadmus-cr-14-sandbox-definition.git`,
   revision `main`.
2. **Sandboxes → Pool → Create** from that definition; size = number of trainees.
3. **Allocate.** SC1 dominates the time (Chocolatey, JDK, IntelliJ IDEA): count
   on 30–60 minutes for a fresh allocation.
4. Link the pool to the training instance built from the CR-14 training definition.

## Repository layout

```
topology.yml                              hosts, router, network, addressing
provisioning/
├── playbook.yml                          SQ1, OWZ1, then SC1
├── requirements.yml                      roles and collections
├── group_vars/all.yml                    credentials, IPs, images, package list
└── templates/
    ├── sq1-docker-compose.yml.j2         SonarQube
    ├── owz1-docker-compose.yml.j2        OWASP ZAP (Webswing)
    ├── sc1-README.txt.j2                 desktop README on SC1
    └── verify-cr-env.ps1.j2              environment check on SC1
```

## Notes for instructors

- SC1 uses `windows-11-bkp-x86_64` because it is the Windows 11 image the
  platform marks with *GUI access: Yes*. `windows-11-x86_64` (uploaded
  27 Sep 2026) is marked *GUI access: No*, and with it the sandbox service
  reports `gui_access: false` for SC1, so no remote desktop is offered to
  trainees. Once the platform administrators set the GUI flag on
  `windows-11-x86_64`, switching back is a one-line change in `topology.yml`.
- IntelliJ IDEA Ultimate starts in its trial/free mode; activate an
  educational licence if the course needs Ultimate-only features.
- Snyk requires a free account: trainees run `snyk auth` once.

---

Co-funded by the European Union (Digital Europe Programme, grant agreement
101190006 — CADMUS). Views and opinions expressed are those of the author(s)
only and do not necessarily reflect those of the European Union or HaDEA.
