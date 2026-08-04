# ISDP Cloud Functions

## Email delivery

The `createUser` callable sends the new user's temporary password by SMTP.
The `notifyWorkOrderUpdate` trigger emails active supervisors as soon as a new
job enters the supervisor queue, before it is accepted. A job assigned to a
specific supervisor only emails that supervisor; selecting all supervisors
emails every active supervisor. It also emails technicians when they are newly
assigned to a job.

The scheduled `monitorWorkOrderSla` function runs every 15 minutes. It:

- reminds the assigned supervisor when a job has waited 12 hours for
  acceptance, repeating every 12 hours for up to three days;
- warns the assigned supervisor when an open job is due within two hours; and
- escalates an overdue open job to active administrators once.

Set non-secret params in `functions/.env` before deploying:

```ini
SMTP_HOST=smtp.example.com
SMTP_PORT=587
SMTP_SECURE=false
SMTP_FROM="Field Service Platform <no-reply@example.com>"
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
