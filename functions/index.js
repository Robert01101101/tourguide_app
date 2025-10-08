const {onRequest} = require("firebase-functions/v2/https");
const {onDocumentDeleted} = require("firebase-functions/v2/firestore");
const admin = require("firebase-admin");
const axios = require("axios");
admin.initializeApp();

const validateAuthId = (authId) => {
  return typeof authId === "string" && authId.length > 0 && authId.length < 50;
};

// Unsubscribe user from email category via unsubscribe button in email
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

const fetchDirections = async (req, res) => {
  // Verify the ID token from the Authorization header
  const authHeader = req.headers.authorization;
  if (!authHeader || !authHeader.startsWith("Bearer ")) {
    return res.status(401).send("Unauthorized: No token provided");
  }

  try {
    const originPlaceId = req.query.originPlaceId;
    const destinationPlaceId = req.query.destinationPlaceId;
    const waypoints = req.query.waypoints || "";

    if (!originPlaceId || !destinationPlaceId) {
      return res.status(400).send("Bad Request: missing parameters");
    }

    let attempt = 0;
    let lastAttemptedUrl = "";
    while (attempt < 2) {
      try {
        const mode = attempt == 0 ? "walking" : "driving";
        const baseUrl = "https://maps.googleapis.com/maps/api/directions/json";
        const url = `${baseUrl}?origin=place_id:${originPlaceId}` +
          `&destination=place_id:${destinationPlaceId}&` +
          `${waypoints ? `waypoints=${waypoints}&` : ""}` +
          `mode=${mode}&key=${process.env.MAPS_API_KEY}`;
        lastAttemptedUrl = url;

        console.log("Request url: " + url);

        const response = await axios.get(url);

        if (response.status === 200) {
          const data = response.data;
          const status = data.status;

          console.log("Response data: " + data);

          if (status === "ZERO_RESULTS") {
            attempt++;
            continue;
          }

          const points = data.routes[0].overview_polyline.points;
          console.log("Sending points: " + points);
          return res.status(200).send({points});
        } else {
          throw new Error("Failed to load directions");
        }
      } catch (error) {
        attempt++;
        if (attempt >= 2) {
          return res.status(500).send("Failed to get directions with params:"+
            " \n originPlaceId=" + originPlaceId + ", destinationPlaceId=" +
            destinationPlaceId + ", waypoints=" + waypoints +
            " \n lastAttemptedUrl=" + lastAttemptedUrl + " \nError: " +error);
        }
      }
    }
  } catch (error) {
    console.error("Authentication error:", error);
    return res.status(401).send("Unauthorized: Invalid token");
  }
};

exports.fetchDirections = onRequest({cors: true}, fetchDirections);

// Cloud Function to recalculate tour ratings when a rating document is deleted.
// For when a user is deleted. Triggered when a rating document is deleted.
exports.recalculateTourRatingsOnRatingDelete = onDocumentDeleted(
  "tours/{tourId}/ratings/{ratingId}",
  async (event) => {
    const tourId = event.params.tourId;
    const db = admin.firestore();

    // Get all remaining ratings for this tour
    const ratingsSnapshot = await db.collection("tours")
        .doc(tourId).collection("ratings").get();

    let upvotes = 0;
    let downvotes = 0;

    // Recalculate upvotes and downvotes
    ratingsSnapshot.forEach((doc) => {
      const rating = doc.data().value;
      if (rating === 1) {
        upvotes++;
      } else if (rating === -1) {
        downvotes++;
      }
    });

    // Update the tour document with the new counts
    await db.collection("tours").doc(tourId).update({
      upvotes: upvotes,
      downvotes: downvotes,
    });

    console.log(`Recalculated ratings for tour:
      ${tourId}, upvotes: ${upvotes}, downvotes: ${downvotes}`);
  }
);