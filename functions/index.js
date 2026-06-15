const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { initializeApp } = require("firebase-admin/app");
const { getAuth } = require("firebase-admin/auth");
const { FieldValue, getFirestore } = require("firebase-admin/firestore");

initializeApp();

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

function cleanString(value) {
  return typeof value === "string" ? value.trim() : "";
}
