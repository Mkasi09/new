# Firebase cost optimisation rollout

The application now uses bounded or role-filtered work-order queries, one shared snapshot stream for data and sync state, counter documents for unread chat, targeted notification recipients, and browser/device caching for evidence photos.

## What changed

- Administrators receive the latest 45 days of jobs instead of the entire lifetime history.
- Supervisors receive open jobs only.
- Technicians receive only open jobs assigned to their UID.
- `watchSyncStatus` and `watchWorkOrders` share one Firestore subscription.
- Chat totals use `users/{uid}/chat_unread` rather than one message and one read listener per job.
- Notification functions query role groups or fetch recipient UIDs directly.
- Chat messages update the parent work order once rather than once in the client and again in a function.
- Evidence responses may be cached privately for one day.

## Required rollout order

The app is not live yet, so no data migration is required. Start production with an empty `work_orders` collection so every job is created with the optimized UID and query fields.

1. Deploy indexes and rules:

   ```powershell
   cd C:\dev\ISDP
   firebase deploy --only firestore:rules,firestore:indexes --project phepha-mv-isdp
   ```

2. Wait until both composite indexes show `Enabled` in the Firebase console.
3. Deploy Functions:

   ```powershell
   cd C:\dev\ISDP
   firebase deploy --only functions --project phepha-mv-isdp
   ```

4. Release the updated Flutter app.
5. Create users before creating work orders, then verify new jobs contain `assignedTechnicianIds`, `supervisorId`, and `isOpen` as they move through the workflow.
6. Run the load test and inspect Firestore Usage and billing after a full workday.

## Compatibility notes

- Approved work orders remain stored but are excluded from supervisor and technician live queues. Administrators retain a rolling 45-day operational history.
