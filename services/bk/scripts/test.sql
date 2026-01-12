-- insert into dir (uid, name) values (gen_random_uuid(), 'base-folder');

-- SELECT id, uid, name FROM dir JOIN link ON (dir.uid = link.parent) WHERE dir.uid = '';

-- '018fa35a-d251-f067-eeb5-deb77e9e2037'
UPDATE entry SET uid = '018fa35a-d251-f067-eeb5-deb77e9e2037' WHERE name = 'messages';

-- INSERT INTO entry_tag (entry, tag)
-- SELECT entry.id, tag.id FROM entry, tag
-- WHERE
--     entry.uid = '018fa32a-6382-06a7-f648-7210b0537c42'
--     AND tag.name = 'tools'
-- ON CONFLICT ON CONSTRAINT unique_id_pair DO NOTHING;

-- INSERT INTO entry_tag (entry, tag)
-- SELECT entry.id, tag.id FROM entry, tag
-- WHERE
--     entry.uid = '018fa32a-6382-06a7-f648-7210b0537c42'
--     AND tag.name = ANY(array['art', 'tools', 'z'])
-- ON CONFLICT ON CONSTRAINT unique_id_pair DO NOTHING;
--SELECT * FROM entry_tag;


-- INSERT INTO tag (name) VALUES ('tools') ON CONFLICT DO NOTHING RETURNING id, name;
-- SELECT * from tag;
-- SELECT * FROM tag WHERE name = ANY(array['web', 'tools', 'z']);

WITH
  existing_tag AS (
    SELECT id, name FROM tag WHERE name = 'z'
  ),
  ins AS (
    INSERT INTO tag(name)
    VALUES ('z')
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
  entry.uid = '018fa35a-d251-f067-eeb5-deb77e9e2037'
ON CONFLICT ON CONSTRAINT unique_id_pair DO NOTHING;


SELECT e.*, array_remove(array_agg(tag.name), NULL)
FROM entry e
LEFT JOIN entry_tag et ON (et.entry = e.id)
LEFT JOIN tag          ON (et.tag   = tag.id)
WHERE e.uid = '018fa35a-d251-f067-eeb5-deb77e9e2037'
GROUP BY e.id;

SELECT * FROM entry_tag et
JOIN tag   ON et.tag   = tag.id
JOIN entry ON et.entry = entry.id
WHERE
  tag.name = 'z'
  AND entry.uid = '018fa35a-d251-f067-eeb5-deb77e9e2037';

-- DELETE FROM entry_tag et
-- USING tag, entry
-- WHERE
--   et.entry = entry.id
--   AND et.tag = tag.id
--   AND tag.name = 'z'
--   AND entry.uid = '018fa35a-d251-f067-eeb5-deb77e9e2037';

