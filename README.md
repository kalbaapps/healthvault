# HealthVault

Upload any medical report, understand it in your language, and track your health over time.

## Structure
- `app/` — Flutter Android app (iOS/web later)
- `server/` — Node/TypeScript API (holds the Claude API key; the app never does) — `npm install coming nextcoming next npm run dev` (copy `server/.env.example` to `server/.env` and set `GEMINI_API_KEY`; `PROVIDER=claude` also supported)

## Run the app
```
cd app
flutter run
```
