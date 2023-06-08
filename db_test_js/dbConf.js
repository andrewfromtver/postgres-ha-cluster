"use strict";

const { Pool } = require("pg");

const dbConfig = {
  host: process.env.DB_HOST,
  user: process.env.DB_USER,
  database: process.env.DB_NAME,
  password: process.env.DB_PASSWORD,
  port: process.env.DB_PORT,
};

module.exports = {
  pool: new Pool(dbConfig),
};
