"use strict";

const { selectPayload, insertPayload, vacuumPayload } = require("./payload.js");

vacuumPayload();
selectPayload();
insertPayload();
