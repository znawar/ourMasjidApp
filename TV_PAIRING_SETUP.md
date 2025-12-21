# TV Pairing Setup (Persistent)

This project supports pairing a TV screen to a masjid using a 6‑digit code.

## What you need in Firebase

1. Firestore enabled.
2. Firestore rules updated to allow:
   - Public read of `masjids/*` (TV + mobile search)
   - Public read of `tv_pairs/*` (TV waits for admin claim)
   - Authenticated write/claim of `tv_pairs/*` (admin web)

A ready-to-copy rules template is in `firestore.rules` at the repo root.

## Run locally (two Chrome tabs)

### 1) TV (main app)

From repo root:

```powershell
cd c:\MasjidConnect\masjidconnect
flutter run -d chrome --web-port 52321 --web-launch-url "http://localhost:52321/?mode=tv"
```

Open: `http://localhost:52321/?mode=tv`

Expected: TV shows a **6-digit pairing code**.

### 2) Admin Web

In a second terminal:

```powershell
cd c:\MasjidConnect\masjidconnect\admin_web
flutter run -d chrome --web-port 52322
```

Open: `http://localhost:52322/`

Sign in.

## Pair a TV

1. On the TV tab, note the 6-digit code.
2. In Admin Web:
   - Go to **Settings → TV Display Settings → Pair a TV (recommended)**
   - Enter the code
   - Click **Pair**
3. Expected: TV switches automatically from the pairing screen to the normal TV display.

## Test persistence

- Refresh the TV tab (Ctrl+R)
- Expected: it should go straight to normal TV display (no pairing code).

## Reset / Re-pair

Open TV with:

- `http://localhost:52321/?mode=tv&reset=1`

This clears the saved pairing and shows a new code.
