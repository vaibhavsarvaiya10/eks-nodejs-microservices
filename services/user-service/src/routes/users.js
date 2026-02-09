const express = require("express");
const router = express.Router();

// Fake in-memory store (fine for POC)
const users = {};

router.post("/", (req, res) => {
  const id = Date.now().toString();
  users[id] = { id, ...req.body };
  res.status(201).json(users[id]);
});

router.get("/:id", (req, res) => {
  const user = users[req.params.id];
  if (!user) {
    return res.status(404).json({ error: "User not found" });
  }
  res.json(user);
});

module.exports = router;
