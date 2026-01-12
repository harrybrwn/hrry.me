SELECT 'dir'   as name, COUNT(*) FROM dir
UNION
SELECT 'entry' as name, COUNT(*) FROM entry
UNION
SELECT 'link'  as name, COUNT(*) FROM link
UNION
SELECT 'tag'   as name, COUNT(*) FROM tag;
