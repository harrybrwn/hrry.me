SELECT t.name
FROM entry_tag et
JOIN entry e ON (et.entry = e.id)
JOIN tag   t ON (et.tag   = t.id)
WHERE e.uid = $1
