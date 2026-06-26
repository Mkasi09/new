const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { onDocumentCreated, onDocumentWritten } = require("firebase-functions/v2/firestore");
const { initializeApp } = require("firebase-admin/app");
const { getAuth } = require("firebase-admin/auth");
const { FieldValue, getFirestore } = require("firebase-admin/firestore");
const { getMessaging } = require("firebase-admin/messaging");
const { defineSecret, defineString } = require("firebase-functions/params");

initializeApp();

const huaweiClientId = defineString("HUAWEI_CLIENT_ID");
const huaweiProjectId = defineString("HUAWEI_PROJECT_ID");
const huaweiAppId = defineString("HUAWEI_APP_ID");
const huaweiClientSecret = defineSecret("HUAWEI_CLIENT_SECRET");
const huaweiSecrets = [huaweiClientSecret];

exports.createUser = onCall(async (request) => {
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
  const temporaryPassword = String(request.data.temporaryPassword || "");
  const role = cleanString(request.data.role);
  const team = cleanString(request.data.team);

  if (!name || !email.includes("@")) {
    throw new HttpsError("invalid-argument", "A valid name and email are required.");
  }
  if (temporaryPassword.length < 8) {
    throw new HttpsError("invalid-argument", "The temporary password is too short.");
  }
  if (!["admin", "supervisor", "technician"].includes(role)) {
    throw new HttpsError("invalid-argument", "Select a valid user role.");
  }

  let user;
  try {
    user = await getAuth().createUser({
      email,
      password: temporaryPassword,
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
    return { uid: user.uid };
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

exports.sendTestNotification = onCall({ secrets: huaweiSecrets }, async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Sign in before testing notifications.");
  }

  const user = await getFirestore().collection("users").doc(request.auth.uid).get();
  if (!user.exists) {
    throw new HttpsError("not-found", "Your user profile was not found.");
  }

  const tokens = tokensForUsers([user]);
  console.log("sendTestNotification", {
    uid: request.auth.uid,
    fcmTokens: tokens.fcm.length,
    hmsTokens: tokens.hms.length,
  });
  if (tokens.fcm.length === 0 && tokens.hms.length === 0) {
    throw new HttpsError(
      "failed-precondition",
      "This phone is not registered for notifications yet.",
    );
  }

  const result = await sendToTokens(tokens, {
    notification: {
      title: "PHEPHA MV ISDP",
      body: "Test notification received. Phone alerts are working.",
    },
    data: {
      type: "notification_test",
      title: "PHEPHA MV ISDP",
      body: "Test notification received. Phone alerts are working.",
    },
  });

  return result;
});

exports.notifyWorkOrderUpdate = onDocumentWritten(
  {
    document: "work_orders/{orderId}",
    secrets: huaweiSecrets,
  },
  async (event) => {
    const before = event.data?.before.exists ? event.data.before.data() : null;
    const after = event.data?.after.exists ? event.data.after.data() : null;
    if (!after) return;

    const notification = notificationForWorkOrder(event.params.orderId, before, after);
    if (!notification) return;

    const users = await getFirestore().collection("users").get();
    const recipients = users.docs.filter((doc) =>
      shouldNotifyUser(doc.id, doc.data(), notification.audience, after),
    );
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

    await db.collection("work_orders").doc(event.params.orderId).update({
      lastMessage: text,
      lastMessageAt: FieldValue.serverTimestamp(),
      lastMessageBy: senderName,
      chatMessageCount: FieldValue.increment(1),
    });

    const users = await db.collection("users").get();
    const recipients = users.docs.filter((doc) =>
      doc.id !== senderId && shouldNotifyUser(doc.id, doc.data(), "field_team", order),
    );
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

function shouldNotifyUser(uid, user, audience, order) {
  const role = cleanString(user.role).toLowerCase();
  if (audience === "admins") return role === "admin";
  if (audience === "supervisors") {
    return role === "admin" || role === "supervisor" || matchesPerson(uid, user, order.supervisor);
  }
  if (audience === "technicians") {
    return role === "technician" && matchesAnyTechnician(uid, user, order);
  }
  if (audience === "field_team") {
    return role === "admin" ||
      matchesPerson(uid, user, order.supervisor) ||
      matchesAnyTechnician(uid, user, order);
  }
  return false;
}

function matchesAnyTechnician(uid, user, order) {
  const values = [
    order.assignedTo,
    ...(Array.isArray(order.assignedTechnicians) ? order.assignedTechnicians : []),
  ];
  return values.some((value) => matchesPerson(uid, user, value));
}

function matchesPerson(uid, user, value) {
  const target = cleanString(value).toLowerCase();
  if (!target) return false;
  const candidates = [
    uid,
    user.uid,
    user.name,
    user.email,
    displayNameFromEmail(user.email),
  ].map((item) => cleanString(item).toLowerCase()).filter(Boolean);
  return candidates.includes(target);
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
    const response = await messaging.sendEachForMulticast({ tokens: batch, ...message });
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

  const projectId = cleanString(huaweiProjectId.value());
  const appId = cleanString(huaweiAppId.value());
  if (!projectId && !appId) {
    console.warn("HMS tokens found, but HUAWEI_PROJECT_ID or HUAWEI_APP_ID is not configured.");
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
      `https://push-api.cloud.huawei.com/v2/${projectId || appId}/messages:send`,
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

  const clientId = cleanString(huaweiClientId.value());
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
    cleanString(before.assignedTo) !== cleanString(after.assignedTo);
}

function evidenceChanged(before, after) {
  return JSON.stringify(before.evidencePhotos || {}) !==
    JSON.stringify(after.evidencePhotos || {}) ||
    JSON.stringify(before.evidenceSlots || []) !==
    JSON.stringify(after.evidenceSlots || []);
}

function displayNameFromEmail(email) {
  const localPart = cleanString(email).split("@")[0];
  if (!localPart) return "";
  return localPart
    .split(/[._-]+/)
    .filter(Boolean)
    .map((part) => `${part.charAt(0).toUpperCase()}${part.slice(1)}`)
    .join(" ");
}

function cleanString(value) {
  return typeof value === "string" ? value.trim() : "";
}
