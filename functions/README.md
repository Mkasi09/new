# ISDP Cloud Functions

## New user email delivery

The `createUser` callable sends the new user's temporary password by SMTP.
Set non-secret params in `functions/.env` before deploying:

```ini
SMTP_HOST=smtp.example.com
SMTP_PORT=587
SMTP_SECURE=false
SMTP_FROM="PHEPHA MV ISDP <no-reply@example.com>"
```

Set SMTP credentials as Firebase secrets:

```powershell
firebase functions:secrets:set SMTP_USER
firebase functions:secrets:set SMTP_PASS
```

Then deploy the functions:

```powershell
npm run deploy
```

If SMTP is not configured, `createUser` stops before creating the account and
the admin screen shows an email setup error.
