# Google Play Data Safety Declaration

This worksheet reflects the Android app code reviewed on 7 July 2026. Confirm
the deployed Firebase/Huawei configuration and organisational retention policy
before submitting the answers in Play Console.

## Overview answers

- **Does the app collect or share required user data types?** Yes, it collects
  data required for account and field-service functionality.
- **Is all collected user data encrypted in transit?** Yes.
- **Can users request deletion of their data?** Yes, by emailing
  itsupport@phephasecurity.co.za. Account provisioning and closure are managed
  by authorised administrators.
- **Does the app sell user data?** No.
- **Is data used for advertising or marketing?** No.
- **Is the app independently security reviewed?** Do not claim this unless a
  qualifying independent review has been completed.
- **Does the app provide account creation?** No self-service account creation;
  authorised administrators provision organisational accounts.

## Data-type mapping

| Play data category | Collected | Shared | Purpose | Required/optional | Processing notes |
|---|---:|---:|---|---|---|
| Personal info — Name | Yes | No | Account management, app functionality, communications | Required | User profile and message attribution |
| Personal info — Email address | Yes | No | Authentication, account management, password recovery, support | Required | Work email |
| Personal info — User IDs | Yes | No | Authentication, access control, audit history, notifications | Required | Firebase UID and role assignment |
| Photos and videos — Photos | Yes | No | App functionality | Optional per workflow, but may be required to complete a job | Before/after job evidence |
| Files and docs | Yes | No | App functionality | Optional/required by workflow | Generated invoices and job evidence records; review Play's current interpretation for in-app-generated PDFs |
| App activity — Other user-generated content | Yes | No | App functionality, account management | Required when using relevant features | Work orders, notes, issue reports, customer name/signature, messages, support requests |
| App activity — App interactions | Yes | No | App functionality, security, compliance | Required | Workflow actions, assignment, approval and read states |
| Device or other IDs | Yes | No | App functionality | Optional | Firebase/Huawei push-notification token; no advertising ID |
| Approximate location | No | No | — | — | Not requested |
| Precise location | No | No | — | — | Not requested; job/site addresses are entered business records, not device location |
| Contacts | No | No | — | — | Not requested |
| Financial info | No | No | — | — | Invoices concern business work orders; the app does not collect payment-card or bank data |
| Health and fitness | No | No | — | — | Not collected |
| Messages — Emails/SMS | No | No | — | — | Password-reset email is sent by Firebase; app does not read users' email or SMS |
| Audio | No | No | — | — | Microphone permission is not requested |
| Web browsing | No | No | — | — | Not collected |
| Calendar | No | No | — | — | Not collected |

## Sharing interpretation

Google Firebase and Huawei Push Kit act as service providers processing data on
behalf of PHEPHA MV. Under Google Play's service-provider exception, these
transfers are generally declared as collection rather than sharing. Reassess
this answer if data is sent to another company for its own purposes or if the
production configuration adds analytics, advertising, crash reporting, or
other SDKs.

## Purposes to select

- App functionality
- Account management
- Developer communications (only for support and operational notifications)
- Security, fraud prevention, and compliance (access controls and audit history)

Do not select advertising or marketing, personalisation, or analytics for the
current build.

## Data handling and retention

- Backend data is stored using Firebase services with role-based access rules.
- A limited cache of up to 100 accessible work orders may be stored locally for
  offline recovery.
- Users can clear the local cache in the app; uninstalling removes app-local data.
- Backend deletion/correction requests are handled through support and may be
  subject to operational, contractual, legal, security, and audit retention.

## Android permissions disclosed

| Permission | Reason |
|---|---|
| Internet | Authentication, work-order synchronisation, evidence, messages, and notifications |
| Camera | Site QR scanning and job-evidence capture |
| Notifications | Operational work-order and communication alerts |

## Final pre-submission checks

- Publish the privacy policy at a stable public HTTPS URL.
- Confirm Firebase region, storage location, retention, and subprocessors.
- Confirm Huawei Push Kit is enabled only where intended.
- Confirm no production SDK has added analytics, crash, advertising, location,
  or device-fingerprinting collection.
- Verify the support team can execute access, correction, and deletion requests.
- Recheck Play Console wording because its questionnaire can change.

