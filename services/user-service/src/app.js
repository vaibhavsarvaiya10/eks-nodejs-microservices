const express = require("express");
const userRoutes = require("./routes/users");

const app = express();
app.use(express.json());

app.get("/health", (req, res) => {
  res.status(200).send("OK");
});

app.use("/users", userRoutes);

module.exports = app;
