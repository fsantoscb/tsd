# TSD Production Control

## Setup

```bash
pnpm install
```

## Scripts principais (root)

```bash
pnpm run lint
pnpm run test
pnpm run typecheck
pnpm run build
```

Esses comandos executam o `pnpm -r <script>` para todos os pacotes do workspace.

## Pacotes

- `apps/web`
- `apps/oracle-sync`
- `packages/shared`

## Environment

- O workspace utiliza `pnpm`.
- Dependências de build que exigem aprovação de scripts já estão tratadas (`esbuild`).
- Se for abrir outro terminal e aparecer aviso de `ERR_PNPM_IGNORED_BUILDS`, rode:

```bash
pnpm approve-builds --all
```

Copy each package .env.example to a local .env file and provide secrets locally. Never commit Oracle credentials. The Phase 0 connector does not connect to Oracle.

The automated SharePoint-to-Deputy import is documented in `DEPUTY_SHAREPOINT_AUTOMATION.md`.

## Structure

```text
.
├─ apps/
│  ├─ web/
│  └─ oracle-sync/
├─ packages/
│  └─ shared/
├─ pnpm-workspace.yaml
└─ package.json
```
