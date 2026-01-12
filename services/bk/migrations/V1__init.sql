CREATE TABLE IF NOT EXISTS dir (
  id          BIGSERIAL PRIMARY KEY,
  uid         UUID      UNIQUE NOT NULL,
  name        TEXT      NOT NULL,
  description TEXT
);

CREATE TABLE IF NOT EXISTS entry (
  id          BIGSERIAL PRIMARY KEY,
  uid         UUID      UNIQUE NOT NULL,
  name        TEXT      NOT NULL,
  description TEXT,
  href        TEXT
);

CREATE TABLE IF NOT EXISTS link (
  id     BIGSERIAL PRIMARY KEY,
  uid    UUID      NOT NULL,
  parent UUID      REFERENCES dir(uid),
  UNIQUE (uid, parent)
);

CREATE INDEX IF NOT EXISTS dir_uid_ix   ON dir   (uid);
CREATE INDEX IF NOT EXISTS entry_uid_ix ON entry (uid);

CREATE INDEX IF NOT EXISTS link_uid_ix    ON link (uid);
CREATE INDEX IF NOT EXISTS link_parent_ix ON link (parent);

-- Tags

CREATE TABLE IF NOT EXISTS tag (
  id   SERIAL PRIMARY KEY,
  name VARCHAR(255) UNIQUE NOT NULL
);

CREATE INDEX IF NOT EXISTS tag_name_ix ON tag (name);

CREATE TABLE IF NOT EXISTS entry_tag (
  entry BIGINT REFERENCES entry(id) ON DELETE CASCADE,
  tag   INT    REFERENCES tag(id)   ON DELETE CASCADE,
  CONSTRAINT unique_id_pair UNIQUE (entry, tag)
);

INSERT INTO tag (name)
VALUES
  ('90s'),
  ('art'),
  ('blog'),
  ('books'),
  ('computers'),
  ('dataset'),
  ('economics'),
  ('game'),
  ('math'),
  ('people'),
  ('programming'),
  ('science'),
  ('silly'),
  ('tools'),
  ('web')
ON CONFLICT DO NOTHING;

-- vim: ft=plsql
