const {onRequest} = require("firebase-functions/v2/https");
const admin = require("firebase-admin");
admin.initializeApp();

const validateAuthId = (authId) => {
  return typeof authId === "string" && authId.length > 0 && authId.length < 50;
};

exports.unsubscribeUser = onRequest(async (req, res) => {
  const authId = req.query.authId;

  if (!authId) {
    return res.status(400).send("Auth ID is required");
  }

  if (!validateAuthId(authId)) {
    return res.status(400).send("Invalid Auth ID format");
  }

  try {
    const userRef = admin.firestore().collection("users").doc(authId);
    await userRef.update({emailSubscribed: false});
    return res.send("Successfully unsubscribed from emails.");
  } catch (error) {
    console.error("Error unsubscribing user:", error);
    return res.status(500).send("Internal Server Error");
  }
});
