# Discovery questionnaire

The agent **must** go through this questionnaire before starting a new project (see [BOOTSTRAP.md](../../BOOTSTRAP.md#phase-1--discovery)) and whenever a new large feature changes the project's assumptions.

How to use it:
- Skip questions the user already answered; confirm the ones you inferred.
- Always propose a **recommended default** (column "Default") so the user can accept quickly.
- Areas marked ★ are **mandatory**: never assume silently. Each answer ends up in [PROJECT_CONTEXT.md](PROJECT_CONTEXT.md).
- Prefer the simplest option that meets the stated needs. Do not over-engineer for hypothetical scale.

---

## 1. Vision & scope

| # | Question | Why it matters | Default |
|---|---|---|---|
| 1.1 | What problem does the project solve, and for whom? | Drives every prioritization decision. | — (must be answered) |
| 1.2 | What is explicitly **out of scope** for the first version? | Prevents scope creep. | Anything not in the MVP feature list. |
| 1.3 | What does the MVP need to do to be considered successful? Any measurable success metric? | Defines milestone M1 and acceptance. | 3–5 core user flows working end to end. |
| 1.4 | Is there a deadline or fixed date? | Shapes milestones and trade-offs. | No hard deadline. |
| 1.5 | Is this a prototype/PoC, internal tool, or production product? | Changes the bar for security, testing, ops. | Production-ready MVP. |
| 1.6 | Who are the stakeholders (business, management, clients) who will read the documentation? What do they need to understand? | Shapes the business docs (`docs/business/`). | Product owner and business stakeholders: vision, journeys, roadmap. |
| 1.7 | What are the 2–5 key user journeys? Any domain terms we must use? | Becomes the user-journey flowcharts and glossary. | Derived from the description; confirmed with the user. |

## 2. ★ User interface

| # | Question | Why it matters | Default |
|---|---|---|---|
| 2.1 | Which interfaces: web app, mobile app, desktop, CLI, API only? | Determines stack and effort. | Responsive web app. |
| 2.2 | Who are the user types/personas and roughly how tech-savvy are they? | UX complexity, onboarding. | One end-user persona + one admin. |
| 2.3 | Any design system, brand guidelines or mockups? | Avoids rework. | Use a standard component library (e.g. shadcn/ui, MUI). |
| 2.4 | Languages / i18n? | Text extraction from day one is cheap; later is expensive. | English only, i18n-ready. |
| 2.5 | Accessibility requirements? | Legal + quality. | WCAG 2.1 AA. |
| 2.6 | Devices/browsers to support? Offline needed? | Testing matrix. | Latest 2 versions of evergreen browsers, online only. |

## 3. ★ Data hosting & residency

| # | Question | Why it matters | Default |
|---|---|---|---|
| 3.1 | Where will the application and data be hosted? (Cloud provider: AWS/GCP/Azure/Vercel/Supabase…, on-premise, self-hosted VPS) | Everything else depends on it. | Managed PaaS (e.g. Vercel/Render/Fly) + managed Postgres. |
| 3.2 | Are there data residency constraints (e.g. EU only)? | GDPR / contracts. | EU region. |
| 3.3 | What kinds of data will be stored? Any personal data (PII), health, financial or other sensitive categories? | Security & compliance level. | Basic PII (name, email). |
| 3.4 | Data model shape: relational, document, files/blobs, time-series, search? | Database choice. | Relational (PostgreSQL) + object storage for files. |
| 3.5 | Retention, backup and deletion requirements (RPO/RTO)? | Ops cost and design. | Daily backups, 7-day retention, RPO 24h, RTO 4h; user data deletable on request. |
| 3.6 | Integrations with external systems / data sources? | Dependencies, auth, rate limits. | None for MVP. |

## 4. ★ Scalability & performance

| # | Question | Why it matters | Default |
|---|---|---|---|
| 4.1 | Expected users at launch and in 12 months? Concurrent users at peak? | Sizing. | < 1,000 users, < 50 concurrent. |
| 4.2 | Expected data volume and growth? | Storage, indexing. | < 10 GB in year 1. |
| 4.3 | Latency expectations for key operations? | Architecture (caching, async). | p95 < 500 ms for API reads. |
| 4.4 | Availability target? Is downtime for deploys acceptable? | Infra complexity and cost. | 99.5%, short maintenance windows acceptable. |
| 4.5 | Heavy/background workloads (batch jobs, AI calls, file processing, real-time)? | Queues, workers, websockets. | None; add a job queue only if needed. |

## 5. ★ Security

| # | Question | Why it matters | Default |
|---|---|---|---|
| 5.1 | Compliance frameworks that apply (GDPR, HIPAA, SOC 2, PCI-DSS, ISO 27001…)? | Hard requirements. | GDPR basics. |
| 5.2 | Where are secrets stored? | Never in the repo. | Platform secret store / environment variables; `.env` only locally and git-ignored. |
| 5.3 | Encryption requirements (at rest, in transit, field-level)? | Design. | TLS everywhere, provider-managed encryption at rest. |
| 5.4 | Audit logging required? Which events? | Data model + storage. | Log auth events and admin actions. |
| 5.5 | Threats you are specifically worried about (abuse, scraping, fraud)? | Rate limiting, captcha, WAF. | OWASP Top 10 baseline + rate limiting on auth. |
| 5.6 | Dependency and code scanning in CI? | Supply chain. | Dependabot + secret scanning + language linter security rules. |

## 6. ★ Access control & identity

| # | Question | Why it matters | Default |
|---|---|---|---|
| 6.1 | Do users need accounts? How do they sign in (email+password, magic link, social login, SSO/SAML/OIDC)? | Auth provider choice. | Managed auth provider (e.g. Auth0/Clerk/Supabase Auth/Cognito) with email + Google. |
| 6.2 | Roles and permissions? (e.g. admin, member, viewer) Multi-tenant (organizations/teams)? | Authorization model, data isolation. | Roles: `admin`, `user`. Single tenant. |
| 6.3 | MFA required? For whom? | Security. | Optional for users, required for admins. |
| 6.4 | Self sign-up or invitation only? | Onboarding flows. | Self sign-up with email verification. |
| 6.5 | Who has access to production infrastructure and data? | Least privilege. | Only project owners; access via provider IAM. |
| 6.6 | Session/token lifetime and account lifecycle (lock, delete, export)? | Compliance. | Provider defaults; user can delete account. |

## 7. ★ Cost control

| # | Question | Why it matters | Default |
|---|---|---|---|
| 7.1 | Monthly budget for infrastructure and third-party services? | Rules out options. | < 50 USD/month for MVP. |
| 7.2 | Preference for free tiers / serverless / pay-per-use vs fixed servers? | Cost profile. | Free tiers and pay-per-use first. |
| 7.3 | Paid APIs (e.g. LLMs, maps, SMS)? Expected volume? | Biggest cost risk. | None; if any, set per-user quotas and spending caps. |
| 7.4 | Budget alerts and hard limits? | Avoid surprise bills. | Billing alerts at 50/80/100% of budget. |
| 7.5 | Who pays and who approves new paid services? | Governance. | The project owner approves any new paid service. |

## 8. Operations & observability

| # | Question | Why it matters | Default |
|---|---|---|---|
| 8.1 | Environments needed (local, dev, staging, prod)? | CI/CD design. | local + preview per PR + prod. |
| 8.2 | Deployment strategy and who can deploy? | CI/CD. | Auto-deploy `main` to prod after CI passes. |
| 8.3 | Logging, metrics, error tracking, uptime monitoring? | Diagnose issues. | Structured logs + error tracking (e.g. Sentry free tier) + uptime check. |
| 8.4 | Analytics / product metrics? Cookie consent? | Privacy. | Privacy-friendly analytics or none. |
| 8.5 | Where should the project documentation be published, and who may read it? | Business readers need a link and no installs, but the docs may be confidential. | Cloudflare Pages from `docs-site/`, protected with Cloudflare Access (company emails). Offline copy: `docs-site/index.html`. |

## 9. Technology & team constraints

| # | Question | Why it matters | Default |
|---|---|---|---|
| 9.1 | Preferred or mandatory languages/frameworks? Any to avoid? | Stack. | Agent proposes based on the above; user approves. |
| 9.2 | Who will maintain the project and what is their skill set? | Choose maintainable tech. | The user, with AI assistance. |
| 9.3 | Licensing (open source? which license?) | LICENSE file. | MIT. |
| 9.4 | Git workflow: PRs required? Reviews? | Branch protection. | Feature branches + PR + CI green before merge. |

---

## Output

The agent writes the answers into [PROJECT_CONTEXT.md](PROJECT_CONTEXT.md), marking each decision's source: `user`, `default (accepted)` or `assumption (to validate)`.
