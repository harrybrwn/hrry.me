SELECT d.id, d.uid, d.name, d.description
FROM dir d
LEFT JOIN link l ON (d.uid = l.uid)
WHERE l.parent IS NULL
