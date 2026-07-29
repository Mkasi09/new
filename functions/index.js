const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { onDocumentCreated, onDocumentWritten } = require("firebase-functions/v2/firestore");
const { initializeApp } = require("firebase-admin/app");
const { getAuth } = require("firebase-admin/auth");
const { FieldValue, getFirestore } = require("firebase-admin/firestore");
const { getMessaging } = require("firebase-admin/messaging");
const { defineSecret, defineString } = require("firebase-functions/params");
const { setGlobalOptions } = require("firebase-functions/v2/options");
const nodemailer = require("nodemailer");
const { huaweiPushUrl } = require("./huawei_push");

setGlobalOptions({ region: "africa-south1" });
initializeApp();

const huaweiAppId = defineString("HUAWEI_APP_ID");
const huaweiClientSecret = defineSecret("HUAWEI_CLIENT_SECRET");
const huaweiSecrets = [huaweiClientSecret];
const smtpHost = defineString("SMTP_HOST");
const smtpPort = defineString("SMTP_PORT", { default: "587" });
const smtpSecure = defineString("SMTP_SECURE", { default: "false" });
const smtpFrom = defineString("SMTP_FROM");
const smtpUser = defineSecret("SMTP_USER");
const smtpPass = defineSecret("SMTP_PASS");
const smtpSecrets = [smtpUser, smtpPass];
const DEFAULT_TEMPORARY_PASSWORD = "PHEPHA MV";

exports.createUser = onCall({ secrets: smtpSecrets }, async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Sign in before creating users.");
  }

  const db = getFirestore();
  const caller = await db.collection("users").doc(request.auth.uid).get();
  const callerRole = cleanString(caller.data()?.role).toLowerCase();
  if (!caller.exists || callerRole !== "admin") {
    throw new HttpsError("permission-denied", "Only administrators can create users.");
  }

  const name = cleanString(request.data.name);
  const email = cleanString(request.data.email).toLowerCase();
  const role = cleanString(request.data.role);
  const team = cleanString(request.data.team);

  if (!name || !email.includes("@")) {
    throw new HttpsError("invalid-argument", "A valid name and email are required.");
  }
  if (!["admin", "supervisor", "technician"].includes(role)) {
    throw new HttpsError("invalid-argument", "Select a valid user role.");
  }
  assertSmtpConfigured();

  let user;
  try {
    user = await getAuth().createUser({
      email,
      password: DEFAULT_TEMPORARY_PASSWORD,
      displayName: name,
      emailVerified: false,
    });

    await db.collection("users").doc(user.uid).set({
      name,
      email,
      role,
      team: team || null,
      mustChangePassword: true,
      createdAt: FieldValue.serverTimestamp(),
      createdBy: request.auth.uid,
    });
    await getAuth().setCustomUserClaims(user.uid, { role });
    await sendNewUserEmail({
      email,
      name,
      role,
      temporaryPassword: DEFAULT_TEMPORARY_PASSWORD,
    });
    return { uid: user.uid, emailSent: true };
  } catch (error) {
    if (user) {
      await db.collection("users").doc(user.uid).delete().catch(() => undefined);
      await getAuth().deleteUser(user.uid).catch(() => undefined);
    }
    if (error.code === "auth/email-already-exists") {
      throw new HttpsError("already-exists", "A user with this email already exists.");
    }
    console.error("createUser failed", error);
    throw new HttpsError("internal", "The user could not be created.");
  }
});

function assertSmtpConfigured() {
  if (!isSmtpConfigured()) {
    throw new HttpsError(
      "failed-precondition",
      "Email delivery is not ready yet. Ask IT to finish the email setup.",
    );
  }
}

function isSmtpConfigured() {
  return Boolean(cleanString(smtpHost.value()) && cleanString(smtpFrom.value()) &&
    cleanString(smtpUser.value()) && cleanString(smtpPass.value()));
}

function createSmtpTransporter() {
  const port = Number.parseInt(cleanString(smtpPort.value()) || "587", 10);
  return nodemailer.createTransport({
    host: cleanString(smtpHost.value()),
    port: Number.isFinite(port) ? port : 587,
    secure: smtpSecure.value() === "true" || port === 465,
    auth: {
      user: cleanString(smtpUser.value()),
      pass: cleanString(smtpPass.value()),
    },
  });
}

async function sendNewUserEmail({ email, name, role, temporaryPassword }) {
  const transporter = createSmtpTransporter();
  const safeName = cleanString(name) || "ISDP User";
  const subject = "Your PHEPHA MV ISDP account";
  const text = [
    `Hello ${safeName},`,
    "",
    "Your PHEPHA MV ISDP account has been created.",
    "",
    `Email: ${email}`,
    `Temporary password: ${temporaryPassword}`,
    `Role: ${role}`,
    "",
    "Please sign in and change this password immediately.",
  ].join("\n");

  await transporter.sendMail({
    from: cleanString(smtpFrom.value()),
    to: email,
    subject,
    text,
    html: emailHtml({ safeName, email, role, temporaryPassword }),
  });
}

function emailHtml({ safeName, email, role, temporaryPassword }) {
  return `
    <p>Hello ${escapeHtml(safeName)},</p>
    <p>Your PHEPHA MV ISDP account has been created.</p>
    <p>
      <strong>Email:</strong> ${escapeHtml(email)}<br>
      <strong>Temporary password:</strong> ${escapeHtml(temporaryPassword)}<br>
      <strong>Role:</strong> ${escapeHtml(role)}
    </p>
    <p>Please sign in and change this password immediately.</p>
  `;
}

async function sendAssignmentEmails(db, orderId, before, after) {
  if (!isSmtpConfigured()) {
    console.warn("Assignment email skipped because SMTP is not configured.", { orderId });
    return;
  }

  let assignments = assignmentEmailTargets(before, after);
  let userDocs;

  // New jobs are placed in a shared supervisor queue, so there is no
  // supervisorId until somebody accepts one. Notify the supervisors while the
  // job is still awaiting acceptance instead of emailing the accepting
  // supervisor after the fact.
  if (!before && cleanString(after.status) === "Assigned to Supervisor") {
    const supervisors = await db.collection("users")
      .where("role", "==", "supervisor")
      .get();
    userDocs = supervisors.docs.filter((doc) => doc.data()?.disabled !== true);
    assignments = userDocs.map((doc) => ({
      userId: doc.id,
      role: "supervisor",
    }));
  }

  if (assignments.length === 0) return;

  userDocs ??= await db.getAll(
    ...assignments.map((assignment) => db.collection("users").doc(assignment.userId)),
  );
  const usersById = new Map(userDocs.filter((doc) => doc.exists).map((doc) => [doc.id, doc.data()]));
  const messages = assignments
    .map((assignment) => {
      const user = usersById.get(assignment.userId);
      const email = cleanString(user?.email);
      if (!email.includes("@")) return null;
      return assignmentEmailMessage({
        orderId,
        order: after,
        assignment,
        user,
        email,
      });
    })
    .filter(Boolean);

  if (messages.length === 0) return;

  const transporter = createSmtpTransporter();
  const results = await Promise.allSettled(
    messages.map((message) => transporter.sendMail(message)),
  );
  const failures = results.filter((result) => result.status === "rejected");
  if (failures.length > 0) {
    console.warn("Some assignment emails failed", {
      orderId,
      sent: results.length - failures.length,
      failed: failures.length,
      errors: failures.map((failure) => failure.reason?.message || String(failure.reason)),
    });
  } else {
    console.log("Assignment emails sent", { orderId, sent: results.length });
  }
}

function assignmentEmailTargets(before, after) {
  const targets = [];
  const beforeSupervisorId = cleanString(before?.supervisorId);
  const afterSupervisorId = cleanString(after.supervisorId);
  if (cleanString(after.status) === "Assigned to Supervisor" &&
      afterSupervisorId &&
      afterSupervisorId !== beforeSupervisorId) {
    targets.push({ userId: afterSupervisorId, role: "supervisor" });
  }

  const beforeTechnicianIds = new Set(arrayStrings(before?.assignedTechnicianIds));
  for (const technicianId of arrayStrings(after.assignedTechnicianIds)) {
    if (!beforeTechnicianIds.has(technicianId)) {
      targets.push({ userId: technicianId, role: "technician" });
    }
  }

  return Array.from(new Map(targets.map((target) => [target.userId, target])).values());
}

function assignmentEmailMessage({ orderId, order, assignment, user, email }) {
  const name = cleanString(user?.name) || "ISDP User";
  const site = cleanString(order.site) || orderId;
  const roleLabel = assignment.role === "supervisor" ? "supervisor" : "technician";
  const subject = `Job assigned: ${site}`;
  const details = [
    `Job ID: ${orderId}`,
    `Site: ${site}`,
    cleanString(order.address) ? `Address: ${cleanString(order.address)}` : null,
    cleanString(order.scope) ? `Scope: ${cleanString(order.scope)}` : null,
    cleanString(order.priority) ? `Priority: ${cleanString(order.priority)}` : null,
    cleanString(order.status) ? `Status: ${cleanString(order.status)}` : null,
  ].filter(Boolean);
  const text = [
    `Hello ${name},`,
    "",
    `You have been assigned as ${roleLabel} for this PHEPHA MV ISDP job.`,
    "",
    ...details,
    "",
    "Please open the ISDP app to review the job.",
  ].join("\n");

  return {
    from: cleanString(smtpFrom.value()),
    to: email,
    subject,
    text,
    html: assignmentEmailHtml({ name, roleLabel, details }),
  };
}

function assignmentEmailHtml({ name, roleLabel, details }) {
  return `
    <p>Hello ${escapeHtml(name)},</p>
    <p>You have been assigned as ${escapeHtml(roleLabel)} for this PHEPHA MV ISDP job.</p>
    <ul>
      ${details.map((detail) => `<li>${escapeHtml(detail)}</li>`).join("")}
    </ul>
    <p>Please open the ISDP app to review the job.</p>
  `;
}

exports.notifyWorkOrderUpdate = onDocumentWritten(
  {
    document: "work_orders/{orderId}",
    secrets: [...huaweiSecrets, ...smtpSecrets],
  },
  async (event) => {
    const before = event.data?.before.exists ? event.data.before.data() : null;
    const after = event.data?.after.exists ? event.data.after.data() : null;
    if (!after) return;

    const db = getFirestore();
    await sendAssignmentEmails(db, event.params.orderId, before, after);

    const notification = notificationForWorkOrder(event.params.orderId, before, after);
    if (notification) {
      const recipients = await usersForAudience(db, notification.audience, after);
      const tokens = tokensForUsers(recipients);
      console.log("notifyWorkOrderUpdate", {
        orderId: event.params.orderId,
        type: notification.type,
        audience: notification.audience,
        recipients: recipients.length,
        fcmTokens: tokens.fcm.length,
        hmsTokens: tokens.hms.length,
      });
      if (tokens.fcm.length === 0 && tokens.hms.length === 0) return;

      const result = await sendToTokens(tokens, {
        notification: {
          title: notification.title,
          body: notification.body,
        },
        data: {
          workOrderId: event.params.orderId,
          type: notification.type,
          status: cleanString(after.status),
        },
      });
      console.log("notifyWorkOrderUpdate sent", {
        orderId: event.params.orderId,
        successCount: result.successCount,
        failureCount: result.failureCount,
      });
    }
  },
);

exports.notifyJobChatMessage = onDocumentCreated(
  {
    document: "work_orders/{orderId}/messages/{messageId}",
    secrets: huaweiSecrets,
  },
  async (event) => {
    const message = event.data?.data();
    if (!message) return;

    const db = getFirestore();
    const orderDoc = await db.collection("work_orders").doc(event.params.orderId).get();
    if (!orderDoc.exists) return;

    const order = orderDoc.data();
    const senderId = cleanString(message.senderId);
    const senderName = cleanString(message.senderName) || "ISDP User";
    const site = cleanString(order.site) || "Job chat";
    const text = cleanString(message.message);
    if (!text) return;

    const recipients = (await usersForAudience(db, "field_team", order))
      .filter((doc) => doc.id !== senderId);
    if (recipients.length > 0) {
      const unreadBatch = db.batch();
      for (const recipient of recipients) {
        unreadBatch.set(
          db.collection("users").doc(recipient.id)
            .collection("chat_unread").doc(event.params.orderId),
          {
            orderId: event.params.orderId,
            count: FieldValue.increment(1),
            updatedAt: FieldValue.serverTimestamp(),
          },
          { merge: true },
        );
      }
      await unreadBatch.commit();
    }
    const tokens = tokensForUsers(recipients);
    console.log("notifyJobChatMessage", {
      orderId: event.params.orderId,
      messageId: event.params.messageId,
      recipients: recipients.length,
      fcmTokens: tokens.fcm.length,
      hmsTokens: tokens.hms.length,
    });
    if (tokens.fcm.length === 0 && tokens.hms.length === 0) return;

    await sendToTokens(tokens, {
      notification: {
        title: `${site} chat`,
        body: `${senderName}: ${text.slice(0, 120)}`,
      },
      data: {
        workOrderId: event.params.orderId,
        messageId: event.params.messageId,
        type: "job_chat_message",
      },
    });
  },
);

exports.notifySupportMessage = onDocumentCreated(
  {
    document: "support_messages/{messageId}",
    secrets: huaweiSecrets,
  },
  async (event) => {
    const message = event.data?.data();
    if (!message) return;

    const db = getFirestore();
    const senderId = cleanString(message.senderId);
    const senderName = cleanString(message.senderName) || "ISDP User";
    const text = cleanString(message.message);
    if (!text) return;

    const recipients = (await usersForAudience(db, "admins", {}))
      .filter((doc) => doc.id !== senderId);
    const tokens = tokensForUsers(recipients);
    console.log("notifySupportMessage", {
      messageId: event.params.messageId,
      recipients: recipients.length,
      fcmTokens: tokens.fcm.length,
      hmsTokens: tokens.hms.length,
    });
    if (tokens.fcm.length === 0 && tokens.hms.length === 0) return;

    await sendToTokens(tokens, {
      notification: {
        title: "New support message",
        body: `${senderName}: ${text.slice(0, 120)}`,
      },
      data: {
        messageId: event.params.messageId,
        type: "support_message",
        source: "support",
      },
    });
  },
);

function notificationForWorkOrder(orderId, before, after) {
  const site = cleanString(after.site) || "A work order";
  const status = cleanString(after.status);

  if (!before) {
    return {
      audience: "supervisors",
      type: "work_order_created",
      title: "New work order",
      body: `${site} has been added to the queue.`,
    };
  }

  const beforeStatus = cleanString(before.status);
  if (beforeStatus !== status) {
    if (status === "Dispatched") {
      return {
        audience: "technicians",
        type: "work_order_dispatched",
        title: "Job dispatched",
        body: `${site} has been assigned for field work.`,
      };
    }
    if (status === "On Site") {
      return {
        audience: "supervisors",
        type: "work_order_on_site",
        title: "Arrival confirmed",
        body: `${site} is now on site.`,
      };
    }
    if (status === "Submitted") {
      return {
        audience: "admins",
        type: "work_order_submitted",
        title: "Job submitted",
        body: `${site} is ready for admin review.`,
      };
    }
    if (status === "Approved") {
      return {
        audience: "field_team",
        type: "work_order_approved",
        title: "Job approved",
        body: `${site} has been approved.`,
      };
    }
  }

  if (assignedTechniciansChanged(before, after)) {
    return {
      audience: "technicians",
      type: "work_order_assigned",
      title: "Job assigned",
      body: `${site} has been assigned to you.`,
    };
  }

  if (cleanString(before.issueReport) !== cleanString(after.issueReport) &&
      cleanString(after.issueReport)) {
    return {
      audience: "supervisors",
      type: "issue_reported",
      title: "Issue reported",
      body: `${site}: ${cleanString(after.issueReport)}`,
    };
  }

  if (evidenceChanged(before, after)) {
    return {
      audience: "supervisors",
      type: "evidence_uploaded",
      title: "Evidence uploaded",
      body: `${site} has new evidence photos.`,
    };
  }

  return null;
}

async function usersForAudience(db, audience, order) {
  if (audience === "admins") {
    return (await db.collection("users").where("role", "==", "admin").get()).docs;
  }
  if (audience === "supervisors") {
    return (await db.collection("users")
      .where("role", "in", ["admin", "supervisor"])
      .get()).docs;
  }

  const technicianIds = Array.isArray(order.assignedTechnicianIds)
    ? order.assignedTechnicianIds.map(cleanString).filter(Boolean)
    : [];
  const supervisorId = cleanString(order.supervisorId);

  const ids = new Set(technicianIds);
  if (audience === "field_team" && supervisorId) ids.add(supervisorId);
  let recipients = ids.size > 0
    ? await db.getAll(...Array.from(ids, (uid) => db.collection("users").doc(uid)))
    : [];
  recipients = recipients.filter((doc) => doc.exists);

  if (audience === "field_team") {
    const admins = await db.collection("users").where("role", "==", "admin").get();
    recipients.push(...admins.docs);
  }

  return Array.from(
    new Map(recipients.map((doc) => [doc.id, doc])).values(),
  );
}

function tokensForUsers(users) {
  const fcm = new Set();
  const hms = new Set();
  for (const user of users) {
    const data = user.data();
    for (const token of Array.isArray(data.fcmTokens) ? data.fcmTokens : []) {
      if (cleanString(token)) fcm.add(cleanString(token));
    }
    for (const token of Array.isArray(data.hmsTokens) ? data.hmsTokens : []) {
      if (cleanString(token)) hms.add(cleanString(token));
    }
    const tokenMap = data.notificationTokens || {};
    for (const [token, enabled] of Object.entries(tokenMap)) {
      if (enabled && token) fcm.add(token);
    }
    if (cleanString(data.lastNotificationToken)) {
      fcm.add(cleanString(data.lastNotificationToken));
    }
    if (cleanString(data.lastHuaweiNotificationToken)) {
      hms.add(cleanString(data.lastHuaweiNotificationToken));
    }
  }
  return {
    fcm: Array.from(fcm),
    hms: Array.from(hms),
  };
}

async function sendToTokens(tokens, message) {
  const [fcmResult, hmsResult] = await Promise.all([
    sendToFirebaseTokens(tokens.fcm, message),
    sendToHuaweiTokens(tokens.hms, message),
  ]);
  return {
    successCount: fcmResult.successCount + hmsResult.successCount,
    failureCount: fcmResult.failureCount + hmsResult.failureCount,
    fcm: fcmResult,
    hms: hmsResult,
  };
}

async function sendToFirebaseTokens(tokens, message) {
  const messaging = getMessaging();
  let successCount = 0;
  let failureCount = 0;
  for (let index = 0; index < tokens.length; index += 500) {
    const batch = tokens.slice(index, index + 500);
    const response = await messaging.sendEachForMulticast({
      tokens: batch,
      ...message,
      android: {
        priority: "high",
        notification: {
          channelId: "isdp_work_updates",
          priority: "high",
          defaultSound: true,
          defaultVibrateTimings: true,
        },
      },
    });
    successCount += response.successCount;
    failureCount += response.failureCount;
    if (response.failureCount > 0) {
      console.warn("FCM send failures", response.responses
        .map((item, responseIndex) => ({ index: responseIndex, error: item.error?.message }))
        .filter((item) => item.error));
    }
  }
  return { successCount, failureCount };
}

let huaweiAccessToken = null;
let huaweiAccessTokenExpiresAt = 0;

async function sendToHuaweiTokens(tokens, message) {
  if (tokens.length === 0) {
    return { successCount: 0, failureCount: 0 };
  }

  const appId = cleanString(huaweiAppId.value());
  if (!appId) {
    console.warn("HMS tokens found, but HUAWEI_APP_ID is not configured.");
    return { successCount: 0, failureCount: tokens.length };
  }

  let accessToken;
  try {
    accessToken = await getHuaweiAccessToken();
  } catch (error) {
    console.warn("HMS access token failure", error.message);
    return { successCount: 0, failureCount: tokens.length };
  }
  let successCount = 0;
  let failureCount = 0;
  for (let index = 0; index < tokens.length; index += 500) {
    const batch = tokens.slice(index, index + 500);
    const response = await fetch(
      huaweiPushUrl(appId),
      {
        method: "POST",
        headers: {
          Authorization: `Bearer ${accessToken}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          validate_only: false,
          message: {
            token: batch,
            notification: message.notification,
            data: JSON.stringify(stringValues(message.data || {})),
            android: {
              notification: {
                channel_id: "isdp_work_updates",
                importance: "HIGH",
                use_default_vibrate: true,
                use_default_light: true,
                foreground_show: true,
                click_action: { type: 3 },
              },
            },
          },
        }),
      },
    );
    const payload = await response.json().catch(() => ({}));
    if (response.ok && cleanString(payload.code) === "80000000") {
      successCount += batch.length;
    } else {
      failureCount += batch.length;
      console.warn("HMS send failure", {
        status: response.status,
        code: payload.code,
        msg: payload.msg,
        requestId: payload.requestId,
      });
    }
  }
  return { successCount, failureCount };
}

async function getHuaweiAccessToken() {
  if (huaweiAccessToken && Date.now() < huaweiAccessTokenExpiresAt) {
    return huaweiAccessToken;
  }

  const clientId = cleanString(huaweiAppId.value());
  const clientSecret = cleanString(huaweiClientSecret.value());
  if (!clientId || !clientSecret) {
    throw new Error("Huawei Push Kit server credentials are not configured.");
  }

  const params = new URLSearchParams({
    grant_type: "client_credentials",
    client_id: clientId,
    client_secret: clientSecret,
  });
  const response = await fetch("https://oauth-login.cloud.huawei.com/oauth2/v3/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: params.toString(),
  });
  const payload = await response.json().catch(() => ({}));
  if (!response.ok || !payload.access_token) {
    throw new Error(`Huawei access token request failed: ${response.status} ${payload.error || ""}`);
  }

  huaweiAccessToken = payload.access_token;
  huaweiAccessTokenExpiresAt = Date.now() + (((payload.expires_in || 3600) - 60) * 1000);
  return huaweiAccessToken;
}

function stringValues(data) {
  return Object.fromEntries(
    Object.entries(data)
      .filter(([, value]) => value !== undefined && value !== null)
      .map(([key, value]) => [key, String(value)]),
  );
}

function assignedTechniciansChanged(before, after) {
  return JSON.stringify(before.assignedTechnicians || []) !==
    JSON.stringify(after.assignedTechnicians || []) ||
    JSON.stringify(arrayStrings(before.assignedTechnicianIds)) !==
    JSON.stringify(arrayStrings(after.assignedTechnicianIds)) ||
    cleanString(before.assignedTo) !== cleanString(after.assignedTo);
}

function evidenceChanged(before, after) {
  return JSON.stringify(before.evidencePhotos || {}) !==
    JSON.stringify(after.evidencePhotos || {}) ||
    JSON.stringify(before.evidenceSlots || []) !==
    JSON.stringify(after.evidenceSlots || []);
}

function cleanString(value) {
  return typeof value === "string" ? value.trim() : "";
}

function arrayStrings(value) {
  return Array.isArray(value) ? value.map(cleanString).filter(Boolean) : [];
}

function escapeHtml(value) {
  return cleanString(value)
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;")
    .replace(/'/g, "&#39;");
}
