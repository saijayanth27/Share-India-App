/**
 * Import function triggers from their respective submodules:
 *
 * const {onCall} = require("firebase-functions/v2/https");
 * const {onDocumentWritten} = require("firebase-functions/v2/firestore");
 *
 * See a full list of supported triggers at https://firebase.google.com/docs/functions
 */

const { setGlobalOptions } = require("firebase-functions");
const { onRequest } = require("firebase-functions/v2/https");
const admin = require("firebase-admin");
const logger = require("firebase-functions/logger");

admin.initializeApp();

setGlobalOptions({
    maxInstances: 10,
    region: "us-central1" // You can change this to your preferred region
});

/**
 * Webhook to delete a record from Firestore when deleted in Zoho.
 * Triggered by Zoho Creator "On Delete" workflow.
 */
exports.deleteZohoRecord = onRequest(async (req, res) => {
    // Log request details for debugging
    logger.info("Request Headers:", req.headers);
    logger.info("Request Body:", req.body);
    logger.info("Request Query:", req.query);

    // 1. Get Zoho ID from the request
    // We check body (JSON), query (URL params), and even raw body if needed
    let zohoId = req.body.zoho_id || req.query.zoho_id;

    // Sometimes Zoho sends data in a way that requires manual parsing if it's not JSON
    if (!zohoId && typeof req.body === 'string') {
        try {
            const parsed = JSON.parse(req.body);
            zohoId = parsed.zoho_id;
        } catch (e) {
            // Not JSON string, maybe form-encoded or just a raw ID?
            if (req.body.includes('zoho_id=')) {
                zohoId = req.body.split('zoho_id=')[1].split('&')[0];
            }
        }
    }

    if (!zohoId) {
        logger.error("No Zoho ID provided in request");
        return res.status(400).send("Missing zoho_id");
    }

    try {
        logger.info(`Processing deletion for Zoho ID: ${zohoId}`);
        const db = admin.firestore();
        const collectionRef = db.collection("client");

        // 1. Try deleting by Document ID (Most efficient)
        await collectionRef.doc(zohoId.toString()).delete();

        // 2. Also search for any records where the 'zoho_id' FIELD matches
        // This handles cases where the document ID is still the 'family_id' (e.g., VJ001)
        const snapshot = await collectionRef.where("zoho_id", "==", zohoId.toString()).get();

        if (!snapshot.empty) {
            const batch = db.batch();
            snapshot.docs.forEach((doc) => {
                logger.info(`Found and deleting doc with matching zoho_id field: ${doc.id}`);
                batch.delete(doc.ref);
            });
            await batch.commit();
        }

        logger.info(`Successfully processed deletion for Zoho ID: ${zohoId}`);
        return res.status(200).send({ success: true, message: "Deletion processed" });
    } catch (error) {
        logger.error("Error deleting record", error);
        return res.status(500).send({ error: error.message });
    }
});
