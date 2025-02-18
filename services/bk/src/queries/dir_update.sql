UPDATE dir
SET
  name = $2,
  description = $3
WHERE uid = $1
