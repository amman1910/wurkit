const { setGlobalOptions } = require("firebase-functions");
const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const { HttpsError, onCall } = require("firebase-functions/v2/https");
const { defineSecret } = require("firebase-functions/params");
const logger = require("firebase-functions/logger");
const admin = require("firebase-admin");
const crypto = require("crypto");
const OpenAI = require("openai");

admin.initializeApp();

setGlobalOptions({ maxInstances: 10 });

const openAiApiKey = defineSecret("OPENAI_API_KEY");
const AI_RANKING_MODEL = "gpt-5.4-mini";
const AI_RANKING_CACHE_COLLECTION = "aiJobRankings";
const AI_RANKING_CACHE_TTL_MS = 7 * 24 * 60 * 60 * 1000;
const MAX_AI_RANKING_JOBS = 10;
const MAX_AI_RANKING_RESULTS = 5;

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

exports.deleteEmployerAccount = onCall(async (request) => {
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
  const profileRef = db.collection("employerProfiles").doc(uid);
  const userDoc = await userRef.get();

  if (!userDoc.exists) {
    throw new HttpsError("not-found", "User account document not found.");
  }

  const userData = userDoc.data() || {};
  if (userData.role !== "employer") {
    throw new HttpsError(
      "permission-denied",
      "Only employer accounts can be deleted from this screen."
    );
  }

  logger.info("Employer account deletion started", { uid });

  const deletedBusiness = "Deleted business";
  const jobUpdate = {
    employerDeleted: true,
    businessDeleted: true,
    businessName: deletedBusiness,
    businessLogoUrl: null,
    status: "closed",
    isActive: false,
    isDeleted: true,
    deletedAt: now,
    updatedAt: now,
  };
  const businessSideUpdate = {
    employerDeleted: true,
    businessDeleted: true,
    businessName: deletedBusiness,
    businessLogoUrl: null,
    deletedAt: now,
    updatedAt: now,
  };
  const chatUpdate = {
    employerDeleted: true,
    businessDeleted: true,
    businessName: deletedBusiness,
    businessLogoUrl: null,
    isActive: false,
    deletedAt: now,
    updatedAt: now,
    participantNames: { [uid]: deletedBusiness },
    participantImages: { [uid]: null },
  };
  const senderNotificationUpdate = {
    senderDeleted: true,
    senderName: deletedBusiness,
    senderImageUrl: null,
    updatedAt: now,
  };

  await Promise.all([
    updateQueryBatch(db.collection("jobs").where("employerId", "==", uid), jobUpdate),
    updateQueryBatch(
      db.collection("applications").where("employerId", "==", uid),
      businessSideUpdate
    ),
    updateQueryBatch(
      db.collection("matches").where("employerId", "==", uid),
      businessSideUpdate
    ),
    deleteQueryBatch(db.collection("notifications").where("userId", "==", uid)),
    updateQueryBatch(
      db.collection("notifications").where("senderId", "==", uid),
      senderNotificationUpdate
    ),
  ]);

  await anonymizeEmployerChats(db, uid, chatUpdate);

  await Promise.all([userRef.delete(), profileRef.delete()]);

  // TODO: Delete non-canonical logo paths if custom Storage paths are added.
  await deleteStoragePathIfExists(
    storage.bucket(),
    `employer_profile_logos/${uid}/business_logo.jpg`
  );

  await authAdmin.deleteUser(uid);

  logger.info("Employer account deletion completed", { uid });
  return { success: true };
});

exports.rankEmployeeJobsWithAI = onCall(
  { secrets: [openAiApiKey] },
  async (request) => {
    const auth = request.auth;
    if (!auth || !auth.uid) {
      throw new HttpsError(
        "unauthenticated",
        "You must be signed in to rank jobs."
      );
    }

    const payload = request.data || {};
    validateRankingPayload(payload, auth.uid);

    const employee = payload.employee;
    const jobs = payload.jobs.slice(0, MAX_AI_RANKING_JOBS);
    const sanitizedEmployee = buildEmployeePromptPayload(employee);
    const sanitizedJobs = jobs.map(buildJobPromptPayload);
    const employeeId = String(employee.employeeId || "").trim();
    const topJobIds = jobs.map((job) => String(job.jobId || "").trim());
    const inputHash = buildStableHash({
      employeeId,
      employee: buildEmployeeHashPayload(sanitizedEmployee),
      jobs: sanitizedJobs.map(buildJobHashPayload),
    });
    const db = admin.firestore();

    const cachedRanking = await getValidCachedRanking({
      db,
      employeeId,
      inputHash,
    });
    if (cachedRanking) {
      return {
        source: "cache",
        ranking: cachedRanking.rankedJobs,
      };
    }

    const apiKey = openAiApiKey.value() || process.env.OPENAI_API_KEY;
    if (!apiKey) {
      logger.error("OpenAI API key is not configured");
      throw new HttpsError(
        "failed-precondition",
        "AI ranking is not configured."
      );
    }

    const client = new OpenAI({ apiKey });
    const prompt = buildOpenAIPrompt({
      employee: sanitizedEmployee,
      jobs: sanitizedJobs,
      expectedOutputFormat: payload.expectedOutputFormat || {},
    });

    let ranking;
    try {
      const response = await client.responses.create({
        model: AI_RANKING_MODEL,
        input: [
          {
            role: "system",
            content:
              "You rank short-term jobs for one employee. Return only valid JSON.",
          },
          {
            role: "user",
            content: prompt,
          },
        ],
        max_output_tokens: 1400,
        text: {
          format: {
            type: "json_schema",
            name: "job_ranking",
            strict: true,
            schema: {
              type: "object",
              additionalProperties: false,
              properties: {
                rankedJobs: {
                  type: "array",
                  maxItems: MAX_AI_RANKING_RESULTS,
                  items: {
                    type: "object",
                    additionalProperties: false,
                    properties: {
                      jobId: { type: "string" },
                      rank: { type: "integer", minimum: 1 },
                      aiScore: { type: "number", minimum: 0, maximum: 100 },
                      reason: { type: "string" },
                      strengths: {
                        type: "array",
                        items: { type: "string" },
                      },
                      weaknesses: {
                        type: "array",
                        items: { type: "string" },
                      },
                    },
                    required: [
                      "jobId",
                      "rank",
                      "aiScore",
                      "reason",
                      "strengths",
                      "weaknesses",
                    ],
                  },
                },
              },
              required: ["rankedJobs"],
            },
          },
        },
      });

      const responseText = extractOpenAIResponseText(response);
      const parsed = JSON.parse(responseText || "{}");
      ranking = validateRankingResponse(parsed, topJobIds);
    } catch (error) {
      logger.error("OpenAI job ranking failed", {
        employeeId,
        topJobIds,
        inputHash,
        message: error && error.message ? error.message : String(error),
      });
      throw new HttpsError(
        "unavailable",
        "AI job ranking is temporarily unavailable."
      );
    }

    await saveRankingCache({
      db,
      employeeId,
      topJobIds,
      inputHash,
      rankedJobs: ranking,
      model: AI_RANKING_MODEL,
    });

    return {
      source: "openai",
      ranking,
    };
  }
);

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

async function anonymizeEmployerChats(db, uid, chatUpdate) {
  const chatRefs = new Map();
  const byEmployer = await db
    .collection("chats")
    .where("employerId", "==", uid)
    .get();
  for (const doc of byEmployer.docs) {
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
        senderName: "Deleted business",
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

function validateRankingPayload(payload, authUid) {
  if (!payload || typeof payload !== "object" || Array.isArray(payload)) {
    throw new HttpsError("invalid-argument", "Ranking payload is required.");
  }

  const employee = payload.employee;
  if (!employee || typeof employee !== "object" || Array.isArray(employee)) {
    throw new HttpsError("invalid-argument", "Employee data is required.");
  }

  const employeeId = String(employee.employeeId || "").trim();
  if (!employeeId) {
    throw new HttpsError("invalid-argument", "Employee ID is required.");
  }

  if (employeeId !== authUid) {
    throw new HttpsError(
      "permission-denied",
      "You can only rank jobs for your own employee profile."
    );
  }

  const jobs = payload.jobs;
  if (!Array.isArray(jobs)) {
    throw new HttpsError("invalid-argument", "Jobs must be an array.");
  }

  if (jobs.length === 0) {
    throw new HttpsError("invalid-argument", "At least one job is required.");
  }

  if (jobs.length > MAX_AI_RANKING_JOBS) {
    throw new HttpsError(
      "invalid-argument",
      `A maximum of ${MAX_AI_RANKING_JOBS} jobs can be ranked.`
    );
  }

  const seenJobIds = new Set();
  for (const job of jobs) {
    if (!job || typeof job !== "object" || Array.isArray(job)) {
      throw new HttpsError("invalid-argument", "Each job must be an object.");
    }

    const jobId = String(job.jobId || "").trim();
    if (!jobId) {
      throw new HttpsError("invalid-argument", "Each job must include jobId.");
    }

    if (seenJobIds.has(jobId)) {
      throw new HttpsError(
        "invalid-argument",
        "Duplicate job IDs are not allowed."
      );
    }
    seenJobIds.add(jobId);
  }

  const forbiddenPath = findForbiddenPrivateField(payload);
  if (forbiddenPath) {
    throw new HttpsError(
      "invalid-argument",
      `Payload contains private or unsupported field: ${forbiddenPath}.`
    );
  }
}

function findForbiddenPrivateField(value, path = "") {
  if (!value || typeof value !== "object") {
    return null;
  }

  if (Array.isArray(value)) {
    for (let index = 0; index < value.length; index += 1) {
      const childPath = findForbiddenPrivateField(value[index], `${path}[${index}]`);
      if (childPath) {
        return childPath;
      }
    }
    return null;
  }

  const forbiddenKeys = new Set([
    "email",
    "emailaddress",
    "phone",
    "phonenumber",
    "mobile",
    "latitude",
    "longitude",
    "lat",
    "lng",
    "coordinates",
    "coordinate",
    "uid",
    "employerid",
  ]);

  for (const [key, child] of Object.entries(value)) {
    const normalizedKey = key.toLowerCase().replace(/[^a-z0-9]/g, "");
    const childPath = path ? `${path}.${key}` : key;
    if (
      forbiddenKeys.has(normalizedKey) ||
      normalizedKey.includes("email") ||
      normalizedKey.includes("phone") ||
      normalizedKey.includes("mobile")
    ) {
      return childPath;
    }

    const nestedPath = findForbiddenPrivateField(child, childPath);
    if (nestedPath) {
      return nestedPath;
    }
  }

  return null;
}

function buildStableHash(value) {
  const normalized = normalizeForHash(value);
  return crypto
    .createHash("sha256")
    .update(JSON.stringify(normalized))
    .digest("hex");
}

function normalizeForHash(value) {
  if (value === null || value === undefined) {
    return null;
  }

  if (Array.isArray(value)) {
    return value.map(normalizeForHash);
  }

  if (typeof value === "object") {
    return Object.keys(value)
      .sort()
      .reduce((target, key) => {
        target[key] = normalizeForHash(value[key]);
        return target;
      }, {});
  }

  if (typeof value === "string") {
    return value.trim();
  }

  if (typeof value === "number") {
    return Number.isFinite(value) ? Number(value.toFixed(4)) : null;
  }

  if (typeof value === "boolean") {
    return value;
  }

  return String(value);
}

function buildEmployeeHashPayload(employee) {
  return pickFields(employee, [
    "employeeId",
    "ageRange",
    "preferredCategories",
    "preferredRoles",
    "preferredJobTypes",
    "skills",
    "availableDays",
    "preferredShiftTypes",
    "experienceLevel",
    "pastExperienceSummary",
    "shortBio",
    "salaryExpectation",
    "preferredWorkRadiusKm",
    "locationSummary",
    "availabilityFlags",
  ]);
}

function buildEmployeePromptPayload(employee) {
  return pickFields(employee, [
    "employeeId",
    "ageRange",
    "preferredCategories",
    "preferredRoles",
    "preferredJobTypes",
    "skills",
    "availableDays",
    "preferredShiftTypes",
    "experienceLevel",
    "pastExperienceSummary",
    "shortBio",
    "salaryExpectation",
    "preferredWorkRadiusKm",
    "locationSummary",
    "availabilityFlags",
  ]);
}

function buildJobHashPayload(job) {
  const employer = job.employer && typeof job.employer === "object"
    ? pickFields(job.employer, [
        "businessName",
        "businessType",
        "businessDescription",
        "businessAddress",
        "hiringCategories",
      ])
    : {};

  return {
    ...pickFields(job, [
      "jobId",
      "title",
      "description",
      "jobCategory",
      "requiredSkills",
      "shifts",
      "dateText",
      "salaryAmount",
      "salaryType",
      "urgent",
      "startAsSoonAsPossible",
      "distanceKm",
      "isWithinPreferredRadius",
    ]),
    employer,
  };
}

function buildJobPromptPayload(job) {
  const employer = job.employer && typeof job.employer === "object"
    ? pickFields(job.employer, [
        "businessName",
        "businessType",
        "businessDescription",
        "businessAddress",
        "hiringCategories",
      ])
    : {};

  return {
    ...pickFields(job, [
      "jobId",
      "title",
      "description",
      "jobCategory",
      "requiredSkills",
      "shifts",
      "dateText",
      "salaryAmount",
      "salaryType",
      "urgent",
      "startAsSoonAsPossible",
      "distanceKm",
      "isWithinPreferredRadius",
    ]),
    employer,
  };
}

function pickFields(source, fields) {
  return fields.reduce((target, field) => {
    if (Object.prototype.hasOwnProperty.call(source, field)) {
      target[field] = source[field];
    }
    return target;
  }, {});
}

function buildOpenAIPrompt({ employee, jobs, expectedOutputFormat }) {
  return JSON.stringify({
    task: "rank_jobs_for_employee",
    productContext:
      "WURKIT is a short-term staffing mobile app for temporary, part-time, urgent, and flexible jobs. Rank by practical worker-job fit, not generic text similarity.",
    rankingRubric: [
      {
        priority: 1,
        factor: "Category and role fit",
        weight: "highest",
        guidance:
          "Compare preferredCategories to jobCategory and employer businessType. Compare preferredRoles to title, requiredSkills, and description. A strong preferred category or role match should usually beat a job that only matches generic skills.",
      },
      {
        priority: 2,
        factor: "Availability and shift fit",
        weight: "very high",
        guidance:
          "Compare availableDays to dateText when available and preferredShiftTypes to shifts. Urgent or ASAP jobs should favor employees with availableNow, canWorkToday, or canWorkOnShortNotice.",
      },
      {
        priority: 3,
        factor: "Distance and preferred radius",
        weight: "high",
        guidance:
          "Use distanceKm and isWithinPreferredRadius strongly. Penalize jobs outside preferredWorkRadiusKm. Slightly farther jobs can rank well if category, role, shifts, and salary are significantly stronger. Very far jobs should not rank highly without exceptional fit.",
      },
      {
        priority: 4,
        factor: "Skills fit",
        weight: "medium-high",
        guidance:
          "Match skills to requiredSkills and description. Skills support the decision but should not dominate category or role fit. Generic skills like teamwork, responsibility, fast learner, and customer service should not outweigh a strong category or role mismatch.",
      },
      {
        priority: 5,
        factor: "Experience fit",
        weight: "medium",
        guidance:
          "Use experienceLevel and pastExperienceSummary. Entry-level workers can fit simple jobs. Prior similar roles should improve ranking.",
      },
      {
        priority: 6,
        factor: "Salary fit",
        weight: "medium",
        guidance:
          "Compare salaryExpectation to salaryAmount when both exist. Reduce suitability if salary is lower than expected. Improve suitability if salary meets or exceeds expectation. Do not over-penalize small salary gaps for highly suitable short-term jobs.",
      },
      {
        priority: 7,
        factor: "Employer and job context",
        weight: "supporting",
        guidance:
          "Use businessType, businessDescription, businessAddress, hiringCategories, title, and description to understand context, but do not let these override core fit.",
      },
    ],
    scoringGuide: {
      "90-100":
        "Excellent fit across category or role, availability, distance, and salary.",
      "75-89": "Strong fit with minor tradeoffs.",
      "60-74": "Reasonable fit with noticeable weaknesses.",
      "40-59": "Weak fit or important mismatch.",
      "0-39":
        "Poor fit, missing critical requirements, very unsuitable, or very far with no exceptional fit.",
      notes: [
        "Use the full score range when jobs differ meaningfully.",
        "Avoid giving all jobs similar scores.",
        "Rank jobs relative to each other, not independently.",
        "Do not rank simply by distance, salary, or number of matching skills.",
      ],
    },
    outputRules: [
      "Return up to 5 top jobs sorted by rank ascending.",
      "rank must start from 1 and aiScore must be 0 to 100.",
      "rankedJobs must include only jobIds from the input.",
      "reason should be short, UI-friendly, and explain the most important reason for the rank.",
      "strengths may include up to 3 concise facts from the provided data, such as category match, shift fit, radius fit, or salary fit.",
      "weaknesses may include up to 3 concise tradeoffs; use an empty array when there are no meaningful weaknesses.",
      "Mention both strengths and tradeoffs when relevant.",
      "Do not invent facts or mention missing data unless it affects ranking.",
      "Do not include chain-of-thought, markdown, or extra fields.",
      "Do not use or request private fields such as email, phone, profile image, raw coordinates, or IDs beyond employeeId and jobId.",
      "Do not include classicScore or any classic matching score.",
    ],
    employee,
    jobs,
    expectedOutputFormat,
  });
}

function validateRankingResponse(response, allowedJobIds) {
  if (!response || typeof response !== "object" || Array.isArray(response)) {
    throw new Error("OpenAI response must be a JSON object.");
  }

  if (!Array.isArray(response.rankedJobs)) {
    throw new Error("OpenAI response missing rankedJobs.");
  }

  const allowed = new Set(allowedJobIds);
  const used = new Set();
  const sanitized = [];

  for (const item of response.rankedJobs) {
    if (!item || typeof item !== "object" || Array.isArray(item)) {
      continue;
    }

    const jobId = String(item.jobId || "").trim();
    if (!allowed.has(jobId) || used.has(jobId)) {
      continue;
    }

    used.add(jobId);
    sanitized.push({
      jobId,
      rank: sanitized.length + 1,
      aiScore: clampScore(item.aiScore),
      reason: truncateText(item.reason, 220),
      strengths: sanitizeStringArray(item.strengths, 3, 120),
      weaknesses: sanitizeStringArray(item.weaknesses, 3, 120),
    });

    if (sanitized.length >= MAX_AI_RANKING_RESULTS) {
      break;
    }
  }

  if (sanitized.length === 0) {
    throw new Error("OpenAI response did not include valid ranked jobs.");
  }

  return sanitized;
}

async function getValidCachedRanking({ db, employeeId, inputHash }) {
  const cacheDoc = await db
    .collection(AI_RANKING_CACHE_COLLECTION)
    .doc(buildRankingCacheDocId(employeeId, inputHash))
    .get();

  if (!cacheDoc.exists) {
    return null;
  }

  const data = cacheDoc.data() || {};
  if (data.inputHash !== inputHash) {
    return null;
  }

  const expiresAt = readDate(data.expiresAt);
  if (!expiresAt || expiresAt.getTime() <= Date.now()) {
    return null;
  }

  if (!Array.isArray(data.rankedJobs)) {
    return null;
  }

  return {
    employeeId: String(data.employeeId || ""),
    topJobIds: Array.isArray(data.topJobIds) ? data.topJobIds : [],
    inputHash: String(data.inputHash || ""),
    rankedJobs: data.rankedJobs,
    model: String(data.model || ""),
    createdAt: data.createdAt || null,
    expiresAt: data.expiresAt || null,
  };
}

async function saveRankingCache({
  db,
  employeeId,
  topJobIds,
  inputHash,
  rankedJobs,
  model,
}) {
  const now = new Date();
  const expiresAt = new Date(now.getTime() + AI_RANKING_CACHE_TTL_MS);
  await db
    .collection(AI_RANKING_CACHE_COLLECTION)
    .doc(buildRankingCacheDocId(employeeId, inputHash))
    .set({
      employeeId,
      topJobIds,
      inputHash,
      rankedJobs,
      model,
      createdAt: admin.firestore.Timestamp.fromDate(now),
      expiresAt: admin.firestore.Timestamp.fromDate(expiresAt),
    });
}

function buildRankingCacheDocId(employeeId, inputHash) {
  return `${String(employeeId).trim()}_${String(inputHash).trim()}`;
}

function extractOpenAIResponseText(response) {
  if (response && typeof response.output_text === "string") {
    return response.output_text;
  }

  const output = response && Array.isArray(response.output)
    ? response.output
    : [];
  const textParts = [];
  for (const item of output) {
    const content = Array.isArray(item.content) ? item.content : [];
    for (const contentItem of content) {
      if (typeof contentItem.text === "string") {
        textParts.push(contentItem.text);
      }
    }
  }
  return textParts.join("");
}

function clampScore(value) {
  const score = Number(value);
  if (!Number.isFinite(score)) {
    return 0;
  }
  return Math.max(0, Math.min(100, Math.round(score)));
}

function sanitizeStringArray(value, maxItems, maxLength) {
  if (!Array.isArray(value)) {
    return [];
  }

  return value
    .map((item) => truncateText(item, maxLength))
    .filter((item) => item.length > 0)
    .slice(0, maxItems);
}

function truncateText(value, maxLength) {
  const text = String(value || "").trim().replace(/\s+/g, " ");
  if (text.length <= maxLength) {
    return text;
  }
  return `${text.slice(0, maxLength).trimEnd()}...`;
}

function readDate(value) {
  if (value && typeof value.toDate === "function") {
    return value.toDate();
  }
  if (value instanceof Date) {
    return value;
  }
  return null;
}
