"use strict";

const { pool } = require("./dbConf.js");

module.exports = {
  vacuumPayload: async () => {
    setInterval(() => {
      try {
        pool.query(
          `
VACUUM;
        `,
          (e, res) => {
            if (e) {
              console.error(e);
              return;
            } else {
              if (res) {
                console.log(res.command);
              } else {
                console.error("Empty response from cluster!");
              }
            }
          }
        );
      } catch (e) {
        console.error(e);
        return;
      }
    }, Number(process.env.COMMAND_INTERVAL));
  },
  // select async loop
  selectPayload: async () => {
    setInterval(() => {
      try {
        pool.query(
          `
WITH RECURSIVE pg_inherit(inhrelid, inhparent) AS
  (SELECT
    inhrelid,
    inhparent
  FROM
    pg_inherits
    UNION
    SELECT child.inhrelid, parent.inhparent
    FROM pg_inherit child, pg_inherits parent
    WHERE child.inhparent = parent.inhrelid),
    pg_inherit_short AS (SELECT * FROM pg_inherit WHERE inhparent NOT IN (SELECT inhrelid FROM pg_inherit))
SELECT
  table_schema,
  TABLE_NAME,
  row_estimate,
  pg_size_pretty(total_bytes) AS total,
  pg_size_pretty(index_bytes) AS INDEX,
  pg_size_pretty(toast_bytes) AS toast,
  pg_size_pretty(table_bytes) AS TABLE
FROM (
  SELECT *, total_bytes-index_bytes-COALESCE(toast_bytes,0) AS table_bytes
    FROM (
      SELECT
        c.oid,
        nspname AS table_schema,
        relname AS TABLE_NAME,
        SUM(c.reltuples) OVER (partition BY parent) AS row_estimate,
        SUM(pg_total_relation_size(c.oid)) OVER (partition BY parent) AS total_bytes,
        SUM(pg_indexes_size(c.oid)) OVER (partition BY parent) AS index_bytes,
        SUM(pg_total_relation_size(reltoastrelid)) OVER (partition BY parent) AS toast_bytes,
        parent
      FROM (
        SELECT
          pg_class.oid,
          reltuples,
          relname,
          relnamespace,
          pg_class.reltoastrelid,
        COALESCE(inhparent, pg_class.oid) parent
  FROM
    pg_class
  LEFT JOIN pg_inherit_short ON inhrelid = oid
  WHERE relkind IN ('r', 'p')) c
  LEFT JOIN pg_namespace n ON n.oid = c.relnamespace) a
  WHERE oid = parent AND table_schema = 'public') a
ORDER BY table_name ASC;
        `,
          (e, res) => {
            if (e) {
              console.error(e);
              return;
            } else {
              if (res) {
                console.log(res.rows);
              } else {
                console.error("Empty response from cluster!");
              }
            }
          }
        );
      } catch (e) {
        console.error(e);
        return;
      }
    }, Number(process.env.COMMAND_INTERVAL));
  },
  // insert async loop
  insertPayload: async () => {
    try {
      pool.query(
        `
CREATE TABLE IF NOT EXISTS test_sessions (
  id serial PRIMARY KEY,
  process VARCHAR (128) NOT NULL,
  created TIMESTAMP NOT NULL
);
CREATE SEQUENCE IF NOT EXISTS test_sessions_sequence start 1 increment 1;
      `,
        (e, res) => {
          if (e) {
            console.error(e);
          } else {
            if (res) {
              console.log('Test table (test_sessions) created successfully');
            } else {
              console.error("Empty response from cluster!");
            }
          }
        }
      );
    } catch (e) {
      console.error(e);
    }
    setInterval(() => {
      try {
        pool.query(
          `
CREATE TABLE IF NOT EXISTS test_sessions (
    id serial PRIMARY KEY,
    process VARCHAR (128) NOT NULL,
    created TIMESTAMP NOT NULL
);
CREATE SEQUENCE IF NOT EXISTS test_sessions_sequence start 1 increment 1;
INSERT INTO test_sessions (
  id,
  process,
  created
)
VALUES(
  nextval('test_sessions_sequence'),
  'Insert payload DB stress test',
  to_timestamp(${Date.now()} / 1000.0)
) ON CONFLICT DO NOTHING;
SELECT count(*) FROM test_sessions;
        `,
          (e, res) => {
            if (e) {
              console.error(e);
            } else {
              if (res) {
                console.log(`OK - ${res[3].rows[0].count} rows inserted`);
              } else {
                console.error("Empty response from cluster!");
              }
            }
          }
        );
      } catch (e) {
        console.error(e);
      }
    }, Number(process.env.COMMAND_INTERVAL));
  },
};
