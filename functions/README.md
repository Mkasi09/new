# ISDP Cloud Functions

## Email delivery

The `createUser` callable creates a unique random temporary password for every
new user and sends it by SMTP. The user must change it on their first sign-in.
The `notifyWorkOrderUpdate` trigger emails active supervisors as soon as a new
job enters the supervisor queue, before it is accepted. A job assigned to a
specific supervisor only emails that supervisor; selecting all supervisors
emails every active supervisor. It also emails technicians when they are newly
assigned to a job.

The scheduled `monitorWorkOrderSla` function runs every 15 minutes. It:

- reminds the assigned supervisor when a job has waited 12 hours for
  acceptance, then sends one follow-up reminder 24 hours later;
- warns the assigned supervisor when an open job is due within two hours; and
- escalates an overdue open job to active administrators once.

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

Each automatic email has a document in the `email_deliveries` collection. It
records pending, sent, or failed delivery and prevents duplicate messages when
a Cloud Function event is delivered more than once. Failed scheduled alerts
are retried by the next 15-minute monitoring run; messages already marked sent
are skipped.
