const express = require("express");
const app = express();

app.get("/", (req, res) => {
  res.send("User service is running 🚀");
});

app.get("/health", (req, res) => {
  res.json({ status: "ok", service: "user-service" });
});

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
  console.log(`User service listening on port ${PORT}`);
});
