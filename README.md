# Mossaid Simple — crafts marketplace (Laravel + Flutter + Postgres)

Simplified reboot of Mossaid on branch `simple/laravel-marketplace`.
**No payments.** Focus: portfolio posts, job requests, likes/comments, and
chat that opens **only after a craftsman accepts a job**.

```
.
├── api/            # Laravel 13 JSON API (Sanctum tokens, Postgres)
├── app-simple/     # Flutter app (email+password, feed, polling chat)
└── docker-compose.yml  # Postgres 16 + API
```

## Run it

```bash
docker compose up --build
# API → http://localhost:8000/api/health
```

Or run the API locally (needs local Postgres):

```bash
cd api
composer install
cp .env.example .env   # set DB_* to your Postgres
php artisan migrate
php artisan serve      # :8000
```

Flutter:

```bash
cd app-simple
flutter pub get && flutter analyze && flutter test
flutter run --dart-define=API_URL=http://localhost:8000/api
# Android emulator → API_URL=http://10.0.2.2:8000/api
```

## How it works (both directions)

| Who | Does what |
|---|---|
| **Craftsman** | Registers (`role=craftsman`), publishes portfolio **posts** (title, trade, city, price hint, photos). Browses open **jobs**, **accepts** one → chat opens. |
| **Client** | Registers (`role=client`), browses/searches posts, **likes** (toggle) + **comments**. Posts **job requests** (trade, city, budget). Chats after accept, marks **completed**. |
| **Chat** | `GET/POST /jobs/{id}/messages` — polling (`?after_id=`, Flutter polls every 5s). `403` until `status=accepted`. Non-participants always `403`. |

## API cheatsheet

```
POST /api/auth/register {name,email,password,password_confirmation,role,phone?,trade?,city?,bio?} → {user,token}
POST /api/auth/login {email,password} → {user,token}
GET  /api/auth/me · POST /api/auth/logout

GET  /api/posts?trade=&city=&q=          # craftsman portfolio feed
POST /api/posts                          # craftsman only
GET/PATCH/DELETE /api/posts/{id}
POST /api/posts/{id}/like                # toggle → {liked,likes_count}
GET/POST /api/posts/{id}/comments

GET  /api/jobs?trade=&city=&status=&q=&mine=1
POST /api/jobs                           # client only
POST /api/jobs/{id}/accept               # craftsman, open→accepted (opens chat)
POST /api/jobs/{id}/complete             # client, accepted→completed
POST /api/jobs/{id}/cancel
GET/POST /api/jobs/{id}/messages         # only after accept, participants only
```

## Tests

```bash
cd api && php artisan test   # MarketplaceTest: full flow incl. chat-before-accept 403
```

## Notes / limits (intentional for v1)

- Auth is email+password via Sanctum (per your choice). No OTP, no roles beyond client/craftsman.
- No queue table clash: Laravel's internal queue lives in `jobs`; marketplace jobs live in `job_requests`.
- Search uses `ILIKE` (Postgres). No realtime sockets — polling only.
- Photos are URL strings (no uploads yet). No admin panel, no push, no escrow.
- Your previous FastAPI work is safe on `main` (+ stashed WIP: `stash@{0}` on main).
