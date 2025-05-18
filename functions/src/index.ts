/**
 * Import function triggers from their respective submodules:
 *
 * import {onCall} from "firebase-functions/v2/https";
 * import {onDocumentWritten} from "firebase-functions/v2/firestore";
 *
 * See a full list of supported triggers at https://firebase.google.com/docs/functions
 */

// import * as functions from "firebase-functions";
import * as admin from "firebase-admin";
// Remove unused imports
// import {onRequest} from "firebase-functions/v2/https";
// import * as logger from "firebase-functions/logger";
// Import the v2 Firestore trigger
import {onDocumentCreated} from "firebase-functions/v2/firestore";

// Start writing functions
// https://firebase.google.com/docs/functions/typescript

// export const helloWorld = onRequest((request, response) => {
//   logger.info("Hello logs!", {structuredData: true});
//   response.send("Hello from Firebase!");
// });

// Initialize Firebase Admin SDK (only once)
try {
  admin.initializeApp(); // Use admin namespace
  console.log("Firebase Admin SDK initialized successfully.");
} catch (error) {
  console.error("Error initializing Firebase Admin SDK:", error);
  // If already initialized, it might throw an error
}

/**
 * Cloud Function triggered when a new message is created in any chat (using v2 syntax).
 * Fetches sender/recipient details and sends a push notification via FCM.
 */
export const onNewChatMessage = onDocumentCreated(
  "chats/{chatId}/messages/{messageId}",
  async (event) => { // v2 uses an 'event' object
    // --- 1. Get message data and context from event ---
    const snapshot = event.data; // The document snapshot
    if (!snapshot) {
      console.log("No data associated with the event");
      return;
    }
    const messageData = snapshot.data();
    const chatId = event.params.chatId; // Params from event object
    const messageId = event.params.messageId;

    console.log(`[${chatId}] New message detected (ID: ${messageId}) (v2 Trigger)`);

    if (!messageData) {
      console.error(`[${chatId}] Message data is missing for message ${messageId}.`);
      return;
    }

    const senderId = messageData.senderId as string | undefined;
    const messageContent = messageData.content as string | undefined;
    const messageType = messageData.type as string | undefined;

    if (!senderId) {
      console.error(`[${chatId}] Sender ID is missing in message ${messageId}.`);
      return;
    }

    // --- 2. Identify Recipient ---
    const participants = chatId.split("_");
    if (participants.length !== 2) {
      console.error(`[${chatId}] Invalid chatId format. Cannot determine participants.`);
      return;
    }
    const recipientId = participants.find((id: string) => id !== senderId); // Add type annotation for id

    if (!recipientId) {
      console.error(
        `[${chatId}] Could not determine recipient ID. Sender: ${senderId}, Participants: ${participants}`
      );
      return;
    }
    console.log(`[${chatId}] Sender: ${senderId}, Recipient: ${recipientId}`);

    // --- 3. Get Sender's Name ---
    let senderName = "Someone"; // Default name
    try {
      const senderDoc = await admin.firestore() // Use admin namespace
        .collection("users")
        .doc(senderId)
        .get();
      if (senderDoc.exists) {
        // Check if sender is an admin
        const isAdmin = senderDoc.data()?.isAdmin === true;
        
        if (isAdmin) {
          // Always use Dr. Ali Kamal for admin users
          senderName = "Dr. Ali Kamal";
          console.log(`[${chatId}] Sender is admin, using doctor name: ${senderName}`);
        } else {
          // For regular users, use their full name
          senderName = senderDoc.data()?.fullName ?? senderName;
        }
      }
    } catch (error) {
      console.error(`[${chatId}] Error fetching sender profile (${senderId}):`, error);
    }
    console.log(`[${chatId}] Sender name: ${senderName}`);

    // --- 4. Get Recipient's FCM Tokens ---
    let recipientTokens: string[] = [];
    try {
      const recipientDoc = await admin.firestore() // Use admin namespace
        .collection("users")
        .doc(recipientId)
        .get();

      if (recipientDoc.exists) {
        const tokensFromDoc = recipientDoc.data()?.fcmTokens;
        if (Array.isArray(tokensFromDoc)) {
          recipientTokens = tokensFromDoc.filter((token): token is string => typeof token === "string" && token.length > 0);
        }
      }
      if (recipientTokens.length === 0) {
        console.log(`[${chatId}] Recipient ${recipientId} has no valid FCM tokens.`);
        return;
      }
      console.log(`[${chatId}] Found ${recipientTokens.length} tokens for recipient ${recipientId}.`);
    } catch (error) {
      console.error(`[${chatId}] Error fetching recipient tokens (${recipientId}):`, error);
      return;
    }

    // --- 5. Construct Notification Payload ---
    let notificationBody = "New message";
    if (messageType === "text" && messageContent) {
      notificationBody = messageContent;
    } else if (messageType === "image") {
      notificationBody = `${senderName} sent an image.`;
    } else if (messageType === "audio") {
      notificationBody = `${senderName} sent a voice message.`;
    } else if (messageType === "document") {
      notificationBody = `${senderName} sent a document.`;
    }

    const maxBodyLength = 150;
    if (notificationBody.length > maxBodyLength) {
      notificationBody = notificationBody.substring(0, maxBodyLength) + "...";
    }

    const payload: admin.messaging.MessagingPayload = {
      notification: {
        title: `New message from ${senderName}`,
        body: notificationBody,
      },
      data: {
        type: "chat_message",
        chatId: chatId,
        senderId: senderId,
        senderName: senderName,
      },
    };

    console.log(`[${chatId}] Preparing to send notification to ${recipientTokens.length} tokens.`);

    // --- 6. Send Notification via FCM ---
    try {
      const response = await admin.messaging().sendToDevice(recipientTokens, payload, { // Use admin namespace
        contentAvailable: true,
        priority: "high",
      });

      console.log(`[${chatId}] FCM send response received: ${response.successCount} successes, ${response.failureCount} failures.`);

      // --- 7. Handle Failures / Cleanup Tokens ---
      if (response.failureCount > 0) {
        const tokensToRemove: string[] = [];
        response.results.forEach((result, index) => {
          const error = result.error;
          if (error) {
            console.error(
              `[${chatId}] Failure sending to token ${recipientTokens[index]}:`, error
            );
            if (
              error.code === "messaging/invalid-registration-token" ||
              error.code === "messaging/registration-token-not-registered"
            ) {
              console.log(`[${chatId}] Scheduling token ${recipientTokens[index]} for removal.`);
              tokensToRemove.push(recipientTokens[index]);
            }
          }
        });

        if (tokensToRemove.length > 0) {
          console.log(`[${chatId}] Removing ${tokensToRemove.length} invalid tokens for user ${recipientId}.`);
          await admin.firestore() // Use admin namespace
            .collection("users")
            .doc(recipientId)
            .update({
              fcmTokens: admin.firestore.FieldValue.arrayRemove(...tokensToRemove), // Use admin namespace
            });
        }
      }
    } catch (error) {
      console.error(`[${chatId}] Error sending FCM message:`, error);
    }

    // No return value needed for v2 triggers
  }
); // Close onDocumentCreated

// Import FieldValue separately if needed for the arrayRemove part
// import { FieldValue } from "firebase-admin/firestore";
