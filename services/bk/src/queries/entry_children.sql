SELECT e.id, e.uid, e.href, e.name, e.description
FROM entry e
JOIN link ON (e.uid = link.uid)
WHERE link.parent = $1
