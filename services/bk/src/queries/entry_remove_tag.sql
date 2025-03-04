DELETE FROM entry_tag et
USING tag, entry
WHERE
  et.entry = entry.id
  AND et.tag = tag.id
  AND tag.name = $2
  AND entry.uid = $1
