const { setGlobalOptions } = require("firebase-functions");
const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const { HttpsError, onCall } = require("firebase-functions/v2/https");
const logger = require("firebase-functions/logger");
const admin = require("firebase-admin");

admin.initializeApp();

setGlobalOptions({ maxInstances: 10 });

exports.sendPushOnNotificationCreated = onDocumentCreated(
  "notifications/{notificationId}",
  async (event) => {
    const notification = event.data && event.data.data();
    const notificationId = event.params.notificationId;

    if (!notification) {
      logger.warn("Missing notification data", { notificationId });
      return;
    }

    logger.info("Notification received", {
      notificationId,
      type: notification.type || "",
      userId: notification.userId || "",
    });

    const receiverId = notification.userId;
    const title = notification.title || "WURKIT";
    const body = notification.body || "You have a new notification";

    if (!receiverId) {
      logger.warn("Missing userId", { notificationId });
      return;
    }

    const userDoc = await admin
      .firestore()
      .collection("users")
      .doc(receiverId)
      .get();

    if (!userDoc.exists) {
      logger.warn("Receiver user document not found", {
        notificationId,
        receiverId,
      });
      return;
    }

    const userData = userDoc.data();
    const fcmToken = userData && userData.fcmToken;

    if (!fcmToken) {
      logger.warn("Missing fcmToken", {
        notificationId,
        receiverId,
      });
      return;
    }

    const message = {
      token: fcmToken,
      notification: {
        title,
        body,
      },
      data: {
        notificationId: String(notificationId || ""),
        type: String(notification.type || ""),
        relatedJobId: String(notification.relatedJobId || ""),
        relatedApplicationId: String(notification.relatedApplicationId || ""),
        relatedChatId: String(notification.relatedChatId || ""),
        senderId: String(notification.senderId || ""),
      },
      android: {
        priority: "high",
        notification: {
          channelId: "default",
          sound: "default",
        },
      },
    };

    try {
      const response = await admin.messaging().send(message);

      logger.info("Push notification sent successfully", {
        notificationId,
        receiverId,
        response,
      });
    } catch (error) {
      logger.error("Failed to send push notification", {
        notificationId,
        receiverId,
        error,
      });
    }
  }
);

exports.deleteEmployeeAccount = onCall(async (request) => {
  const auth = request.auth;
  if (!auth || !auth.uid) {
    throw new HttpsError(
      "unauthenticated",
      "You must be signed in to delete your account."
    );
  }

  const uid = auth.uid;
  const db = admin.firestore();
  const authAdmin = admin.auth();
  const storage = admin.storage();
  const now = admin.firestore.FieldValue.serverTimestamp();

  const userRef = db.collection("users").doc(uid);
  const profileRef = db.collection("employeeProfiles").doc(uid);
  const [userDoc, profileDoc] = await Promise.all([
    userRef.get(),
    profileRef.get(),
  ]);

  if (!userDoc.exists) {
    throw new HttpsError("not-found", "User account document not found.");
  }

  const userData = userDoc.data() || {};
  if (userData.role !== "employee") {
    throw new HttpsError(
      "permission-denied",
      "Only employee accounts can be deleted from this screen."
    );
  }

  const profileData = profileDoc.exists ? profileDoc.data() || {} : {};

  logger.info("Employee account deletion started", { uid });

  const deletedUser = "Deleted user";
  const applicationUpdate = {
    employeeDeleted: true,
    employeeName: deletedUser,
    employeePhotoUrl: null,
    employeeProfileImageUrl: null,
    employeeImageUrl: null,
    deletedAt: now,
    updatedAt: now,
  };
  const matchUpdate = {
    employeeDeleted: true,
    employeeName: deletedUser,
    employeePhotoUrl: null,
    employeeProfileImageUrl: null,
    employeeImageUrl: null,
    deletedAt: now,
    updatedAt: now,
  };
  const chatUpdate = {
    employeeDeleted: true,
    employeeName: deletedUser,
    employeePhotoUrl: null,
    employeeProfileImageUrl: null,
    employeeImageUrl: null,
    isActive: false,
    deletedAt: now,
    updatedAt: now,
    participantNames: { [uid]: deletedUser },
    participantImages: { [uid]: null },
  };
  const senderNotificationUpdate = {
    senderDeleted: true,
    senderName: deletedUser,
    senderImageUrl: null,
    updatedAt: now,
  };

  await Promise.all([
    updateQueryBatch(
      db.collection("applications").where("employeeId", "==", uid),
      applicationUpdate
    ),
    updateQueryBatch(
      db.collection("matches").where("employeeId", "==", uid),
      matchUpdate
    ),
    deleteQueryBatch(db.collection("notifications").where("userId", "==", uid)),
    updateQueryBatch(
      db.collection("notifications").where("senderId", "==", uid),
      senderNotificationUpdate
    ),
    deleteQueryBatch(
      db.collection("employeeJobInteractions").where("employeeId", "==", uid)
    ),
    deleteCollectionPathBatch(db, `users/${uid}/savedJobs`),
  ]);

  await anonymizeEmployeeChats(db, uid, chatUpdate);

  await Promise.all([userRef.delete(), profileRef.delete()]);

  // TODO: Delete profile image from Storage if custom image paths beyond the
  // canonical employee_profile_images/{uid}/profile.jpg path are introduced.
  await deleteStoragePathIfExists(
    storage.bucket(),
    `employee_profile_images/${uid}/profile.jpg`
  );

  await authAdmin.deleteUser(uid);

  logger.info("Employee account deletion completed", { uid });
  return { success: true };
});

async function anonymizeEmployeeChats(db, uid, chatUpdate) {
  const chatRefs = new Map();
  const byEmployee = await db
    .collection("chats")
    .where("employeeId", "==", uid)
    .get();
  for (const doc of byEmployee.docs) {
    chatRefs.set(doc.ref.path, doc.ref);
  }

  const byParticipant = await db
    .collection("chats")
    .where("participants", "array-contains", uid)
    .get();
  for (const doc of byParticipant.docs) {
    chatRefs.set(doc.ref.path, doc.ref);
  }

  for (const chatRef of chatRefs.values()) {
    await updateDocumentRefsBatch(db, [chatRef], chatUpdate);
    await updateQueryBatch(
      chatRef.collection("messages").where("senderId", "==", uid),
      {
        senderDeleted: true,
        senderName: "Deleted user",
        senderPhotoUrl: null,
        senderImageUrl: null,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      }
    );
  }
}

async function updateQueryBatch(query, updateData) {
  const snapshot = await query.get();
  if (snapshot.empty) {
    return;
  }

  await updateDocumentRefsBatch(
    query.firestore,
    snapshot.docs.map((doc) => doc.ref),
    updateData
  );
}

async function deleteQueryBatch(query) {
  const snapshot = await query.get();
  if (snapshot.empty) {
    return;
  }

  for (let start = 0; start < snapshot.docs.length; start += 450) {
    const batch = query.firestore.batch();
    for (const doc of snapshot.docs.slice(start, start + 450)) {
      batch.delete(doc.ref);
    }
    await batch.commit();
  }
}

async function deleteCollectionPathBatch(db, collectionPath) {
  await deleteQueryBatch(db.collection(collectionPath));
}

async function updateDocumentRefsBatch(db, refs, updateData) {
  for (let start = 0; start < refs.length; start += 450) {
    const batch = db.batch();
    for (const ref of refs.slice(start, start + 450)) {
      batch.set(ref, updateData, { merge: true });
    }
    await batch.commit();
  }
}

async function deleteStoragePathIfExists(bucket, path) {
  try {
    await bucket.file(path).delete({ ignoreNotFound: true });
  } catch (error) {
    logger.warn("Profile image deletion skipped", { path, error });
  }
}
