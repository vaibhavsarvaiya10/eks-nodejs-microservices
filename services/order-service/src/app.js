const express = require("express");
const orderRoutes = require("./routes/orders");

const app = express();
app.use(express.json());

app.get("/health", (req, res) => {
  res.status(200).send("OK");
});

app.use("/orders", orderRoutes);

module.exports = app;
