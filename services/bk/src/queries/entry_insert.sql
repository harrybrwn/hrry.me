INSERT INTO
  entry(uid,href,name, description)
VALUES ($1, $2, $3, $4)
RETURNING id
