# Copilot Instructions — ECPay Skill

This is an **AI Skill repository** (Markdown knowledge base), not a traditional software project. There is no build system, no package manager, and no application code. All content is Markdown files consumed by AI coding assistants.

## Architecture

Three-layer knowledge system:

- **`SKILL.md`** — AI entry point: decision trees, navigation, safety rules, test accounts. Routes queries to the correct guide + reference.
- **`guides/`** (25 files, indexed 00-24) — Static integration knowledge with SNAPSHOT parameter tables. Provides process logic, caveats, code examples in 12 languages.
- **`references/`** (19 files, 431 URLs) — Real-time API spec gateway. Each file contains organized URLs pointing to `developers.ecpay.com.tw`. AI uses `web_fetch` on these URLs to get the latest official parameter specs before generating code.

The critical pattern: **guides/ tells you HOW to integrate; references/ gives you the CURRENT spec to integrate against.** When generating API code, always combine both — never rely on guides/ parameter snapshots alone.

### Three HTTP Protocol Modes

| Mode | Auth | Format | Services |
|------|------|--------|----------|
| CMV-SHA256 | CheckMacValue + SHA256 | Form POST | AIO payment |
| AES-JSON | AES-128-CBC | JSON POST | ECPG, invoices, logistics v2, e-tickets |
| CMV-MD5 | CheckMacValue + MD5 | Form POST | Domestic logistics |

### Supporting Files

- **`commands/`** (6 files) — Claude Code slash commands. Navigation only, ≤20 lines each. Do not duplicate SKILL.md logic.
- **`test-vectors/`** — Deterministic test vectors for CheckMacValue (SHA256/MD5) and AES encryption. Used to validate 12-language crypto implementations.
- **`scripts/SDK_PHP/`** — Official ECPay PHP SDK with 134 verified examples. Read-only reference; do not modify.

## Validation Commands

```bash
# Validate AI Section Index line numbers in guides/13, 14, 24
bash scripts/validate-ai-index.sh

# Manually trigger URL check (also runs weekly via GitHub Actions)
# Go to Actions tab → "Validate Reference URLs" → Run workflow
```

CI runs automatically:
- **`validate.yml`**: On PRs that modify guides/13, 14, 24 or the validation script
- **`validate-references.yml`**: Weekly Monday 02:00 UTC + manual trigger

## Key Conventions

### Version Sync (mandatory)

When changing the version number, update ALL of these:
- `SKILL.md` front-matter `version` field
- `SKILL_OPENAI.md` version reference
- `README.md` version badge
- `CHANGELOG.md` new entry (use CRITICAL/HIGH/MEDIUM/LOW severity)

### SNAPSHOT Timestamps

Parameter tables in `guides/` are marked `SNAPSHOT 2026-XX`. When updating a guide's parameter content, update its SNAPSHOT date. AI is instructed to verify these against live specs via `references/` before generating code.

### AI Section Index

`guides/13`, `guides/14`, and `guides/24` contain HTML comment indexes with line number ranges for each language section (e.g., `Python: line 103-157`). After editing these files, **always run `bash scripts/validate-ai-index.sh`** to confirm line numbers still point to correct headings.

### Security-Critical: Timing-Safe Comparison

All crypto verification code **must** use timing-safe comparison functions. Never use `==` or `===` for CheckMacValue/signature validation:

| Language | Function |
|----------|----------|
| PHP | `hash_equals()` |
| Python | `hmac.compare_digest()` |
| Node.js | `crypto.timingSafeEqual()` |
| Go | `subtle.ConstantTimeCompare()` |
| Java | `MessageDigest.isEqual()` |
| C# | `CryptographicOperations.FixedTimeEquals()` |
| Ruby | `Rack::Utils.secure_compare()` |

### references/ Files Format

Each file follows this structure:
1. AI instruction header (blockquote explaining `web_fetch` usage)
2. Last verification date
3. Section headings with one URL per line

Do not change this format. URLs follow the pattern `https://developers.ecpay.com.tw/{numeric_id}.md`.

## Modification Checklist

- [ ] Editing `guides/13`, `14`, or `24`? → Run `bash scripts/validate-ai-index.sh`
- [ ] Changing parameter tables in guides? → Update SNAPSHOT date
- [ ] Bumping version? → Sync across SKILL.md, SKILL_OPENAI.md, README.md, CHANGELOG.md
- [ ] Adding a new language? → Add crypto impl to guides/13+14, E2E to guides/24, update language count in SKILL.md
- [ ] Adding a new API? → Add guide + reference file + update SKILL.md decision tree
- [ ] Modifying `commands/`? → Keep ≤20 lines, navigation focus only
- [ ] `scripts/SDK_PHP/`? → Track official SDK only, no custom changes
