# Receipt Tracker

## Project Structure
- **Backend**: `expense-tracker-api/` — Hono + Drizzle ORM + MySQL
- **Frontend**: `expense_tracker_app/` — Flutter + Riverpod + GoRouter

## Deployment

### Backend (Coolify)
- **Coolify URL**: https://forge.lagablab.com/project/vsso00sggs8s0o4swggkw040/environment/dsosw0cgc4g8840kso80k00k/application/kggggkgcs04ws88cgogs4g8c
- **Production API**: https://api.receipt.lagablab.com
- **Build**: Dockerfile in `expense-tracker-api/`, base directory `/expense-tracker-api`
- **Auto-deploy**: GitHub webhook on `push` to `main` → Coolify rebuilds automatically
- **Git source**: Public GitHub (`lancegab/receipt-tracker`, branch `main`)
- **Linked DB**: MySQL database managed by Coolify (`mysql-database-s4wsks4ckc4sk4swc80kcso8`)

### DB Schema Push
The Dockerfile CMD attempts `drizzle-kit push` on startup but it may fail due to version mismatch (drizzle-kit is a devDependency). When adding new tables:
1. Push schema manually via Coolify Terminal: `npx drizzle-kit push:mysql`
2. Or connect to the production DB from local: `DATABASE_URL="<prod-url>" npx drizzle-kit push:mysql`

### Local Development (Docker Compose)
- `docker-compose.yml` at project root
- DB on host port `3307` (remapped from 3306 to avoid conflict with kios-mysql)
- API on host port `3001` (remapped from 3000 to avoid conflict with dev server)
- Dev server: `cd expense-tracker-api && npm run dev` (port 3000)

### Flutter App
- Build debug APK: `cd expense_tracker_app && flutter build apk --debug`
- Install on device: `adb install -r build/app/outputs/flutter-apk/app-debug.apk`
- API base URL is set via `--dart-define=API_BASE_URL=https://api.receipt.lagablab.com/api`

## Key Commands
```bash
# Backend type check
cd expense-tracker-api && npx tsc --noEmit

# Push DB schema (local)
DATABASE_URL="mysql://app:apppassword@localhost:3307/expense_tracker" npx drizzle-kit push:mysql

# Deploy (just push to main, Coolify auto-deploys)
git push origin main
```
