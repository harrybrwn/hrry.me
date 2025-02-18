SELECT dir.id, dir.uid, dir.name, dir.description
FROM dir
JOIN link ON (dir.uid = link.uid)
WHERE link.parent = $1
