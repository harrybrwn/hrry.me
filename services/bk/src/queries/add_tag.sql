WITH
  existing_tag AS (
    SELECT id, name FROM tag WHERE name = $2
  ),
  ins AS (
    INSERT INTO tag(name)
    VALUES ($2)
    ON CONFLICT DO NOTHING
    RETURNING id, name
  ),
  t AS (
    SELECT * FROM ins
    UNION
    SELECT * FROM existing_tag
  )
INSERT INTO entry_tag (entry, tag)
SELECT entry.id, t.id FROM entry, t
WHERE
  entry.uid = $1
ON CONFLICT ON CONSTRAINT unique_id_pair DO NOTHING
