SELECT d.id, d.uid, d.name, d.description
FROM dir d
JOIN link l ON (d.uid = l.parent)
WHERE l.uid = $1
