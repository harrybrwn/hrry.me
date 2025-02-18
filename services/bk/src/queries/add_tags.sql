WITH
  tnames AS (
    SELECT name
    FROM unnest($2::TEXT[]) as t(name)
  ),
  ins_tag AS (
    INSERT INTO tag (name)
    SELECT name FROM tnames WHERE name NOT IN (SELECT name FROM tag)
    RETURNING id, name
  ),
  all_tags AS (
    SELECT id, name FROM tag WHERE name IN (SELECT name FROM tnames)
    UNION
    SELECT id, name FROM ins_tag
  )
INSERT INTO entry_tag (entry, tag)
SELECT entry.id, tag.id FROM entry, all_tags tag
WHERE  entry.uid = $1
ON CONFLICT ON CONSTRAINT unique_id_pair DO NOTHING
