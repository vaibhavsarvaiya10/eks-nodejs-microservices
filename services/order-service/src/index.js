const express = require("express");
const axios = require("axios");

const app = express();

/**
 * Health check
 */
app.get("/health", (req, res) => {
  res.json({ status: "ok", service: "order-service" });
});

/**
 * Root endpoint
 */
app.get("/", (req, res) => {
  res.send("Order service is running 📦");
});

/**
 * Example service-to-service call
 * (later this will use Kubernetes DNS)
 */
app.get("/orders", async (req, res) => {
  try {
    const userServiceUrl =
      process.env.USER_SERVICE_URL || "http://localhost:3000";

    const userHealth = await axios.get(
      `${userServiceUrl}/health`
    );

    res.json({
      orderId: "order-123",
      userService: userHealth.data
    });
  } catch (err) {
    res.status(500).json({
      error: "Failed to call user-service",
      details: err.message
    });
  }
});

const PORT = process.env.PORT || 3001;
app.listen(PORT, () => {
  console.log(`Order service listening on port ${PORT}`);
});
