# Environment Variables

Server configuration.
- `APP_URL`
- `DATA_DIR`
- `PUBLIC_DIR`
- `SERVER_PORT` default is 3000
- `SERVER_PORT_WS` default is 3001
- `COOKIE_NAME`
- `COOKIE_MAX_AGE`
- `COOKIE_DOMAIN`
- `COOKIE_PATH`
- `COOKIE_HTTP_ONLY`
- `COOKIE_SECURE`

Database config
- `DATABASE_CLIENT` either `sqlite` or `mysql`
- `DATABASE_HOST`
- `DATABASE_PORT`
- `DATABASE_DATABASE`
- `DATABASE_USERNAME`
- `DATABASE_PASSWORD`
- `DATABASE_FILENAME` only when using sqlite (default is `:memory:`)

Paddle is used for payments.
- `PADDLE_API_KEY`
- `PADDLE_SECRET_KEY`


OAuth. For google see <https://console.cloud.google.com/auth/clients?inv=1&invt=AbzK6w&project=vital-petal-335123>
- `AUTH_GOOGLE_CLIENT_ID`
- `AUTH_GOOGLE_CLIENT_SECRET`
- `AUTH_MICROSOFT_CLIENT_ID`
- `AUTH_MICROSOFT_CLIENT_SECRET`
- `AUTH_FACEBOOK_CLIENT_ID`
- `AUTH_FACEBOOK_CLIENT_SECRET`

Emails.
- `MAIL_DOMAIN`
- `MAIL_KEY`
- `MAIL_FROM_ADDRESS`
- `MAIL_FROM_NAME`
- `MAIL_PROVIDER` (I'm currently trying to add this to the upsteam)

# Ads

I'm not yet sure how to setup ads but here are some files that are interesting.

See files:
- `packages/keybr-pages-server/lib/Shell.tsx` Where the ads are setup using both
  `SetupAds` and `ScriptAssets`.
- `packages/thirdparties/lib/ads.tsx` The ads component
- `packages/keybr-assets/lib/assets.tsx` Where `ScriptAssets` are managed.

# Payments

It looks like payments are handled by a service called
[Paddle](https://www.paddle.com/).
