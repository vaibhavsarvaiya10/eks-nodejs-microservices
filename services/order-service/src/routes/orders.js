const express = require("express");
const axios = require("axios");
const router = express.Router();

const USER_SERVICE_URL =
  process.env.USER_SERVICE_URL || "http://user-service:3000";

const orders = {};

router.post("/", async (req, res) => {
  const { userId, item } = req.body;

  try {
    await axios.get(`${USER_SERVICE_URL}/users/${userId}`);
  } catch (err) {
    return res.status(400).json({ error: "Invalid user" });
  }

  const id = Date.now().toString();
  orders[id] = { id, userId, item };

  res.status(201).json(orders[id]);
});

router.get("/:id", (req, res) => {
  const order = orders[req.params.id];
  if (!order) {
    return res.status(404).json({ error: "Order not found" });
  }
  res.json(order);
});

module.exports = router;
