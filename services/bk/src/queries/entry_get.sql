SELECT
  e.id,
  e.href,
  e.name,
  e.description,
  array_remove(array_agg(tag.name), NULL) AS tags
FROM entry e
LEFT JOIN entry_tag et ON (et.entry = e.id)
LEFT JOIN tag          ON (et.tag   = tag.id)
WHERE
  e.uid = $1
GROUP BY e.id
