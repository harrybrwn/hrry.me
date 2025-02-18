UPDATE entry
SET
  href = $2,
  name = $3,
  description = $4
WHERE uid = $1
