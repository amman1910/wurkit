const { setGlobalOptions } = require("firebase-functions");
const { onDocumentCreated } = require("firebase-functions/v2/firestore");
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
