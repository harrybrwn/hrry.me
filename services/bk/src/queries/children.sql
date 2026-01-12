SELECT
  d.id,
  d.uid,
  '' as href,
  d.name,
  d.description,
  1 as is_dir
FROM dir d
JOIN link ON (d.uid = link.uid)
WHERE link.parent = $1
UNION
SELECT
  e.id,
  e.uid,
  e.href,
  e.name,
  e.description,
  0 as is_dir
FROM entry e
JOIN link ON (e.uid = link.uid)
WHERE link.parent = $1
