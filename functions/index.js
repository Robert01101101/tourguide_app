const {onRequest} = require("firebase-functions/v2/https");
const admin = require("firebase-admin");
admin.initializeApp();

const validateAuthId = (authId) => {
  return typeof authId === "string" && authId.length > 0 && authId.length < 50;
};

exports.unsubscribeUser = onRequest(async (req, res) => {
  const authId = req.query.authId;
  const emailCategory = req.query.emailCategory;

  if (!authId) {
    return res.status(400).send("Auth ID is required");
  }

  if (!validateAuthId(authId)) {
    return res.status(400).send("Invalid Auth ID format");
  }

  if (!emailCategory) {
    return res.status(400).send("Email category is required");
  }

  try {
    const userRef = admin.firestore().collection("users").doc(authId);
    const userDoc = await userRef.get();

    if (!userDoc.exists) {
      return res.status(404).send("User not found");
    }

    const userData = userDoc.data();
    const emailsDisabled = userData.emailSubscriptionsDisabled || [];

    if (!emailsDisabled.includes(emailCategory)) {
      emailsDisabled.push(emailCategory);
      await userRef.update({emailSubscriptionsDisabled: emailsDisabled});
    }

    return res.send("Successfully unsubscribed from "+emailCategory+" emails.");
  } catch (error) {
    console.error("Error unsubscribing user:", error);
    return res.status(500).send("Internal Server Error");
  }
});
