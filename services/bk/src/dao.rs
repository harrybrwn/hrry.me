use std::{collections::HashSet, future::Future};

use anyhow::Result;
use deadpool_postgres::{GenericClient as Client, Pool};
use futures::TryStreamExt;
use postgres_types::ToSql;
use serde::{Deserialize, Serialize};
use tokio_postgres::{error::SqlState, Error as PGError, ToStatement};
use ulid::Ulid;

type Id = i64;

#[derive(Debug)]
pub enum ErrorKind {
    NotFound,
    TooManyRows,
    Internal,
}

#[derive(Debug)]
pub struct Error {
    pub kind: ErrorKind,
    pub inner: Option<Box<dyn std::error::Error + Sync + Send>>,
}

impl Error {
    fn new(kind: ErrorKind) -> Self {
        Self { kind, inner: None }
    }

    fn not_found() -> Self {
        Self::new(ErrorKind::NotFound)
    }

    fn too_many() -> Self {
        Self::new(ErrorKind::TooManyRows)
    }
}

impl std::error::Error for Error {}

impl std::fmt::Display for ErrorKind {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            Self::NotFound => f.write_str("not found"),
            Self::TooManyRows => f.write_str("too many results"),
            Self::Internal => f.write_str("internal error"),
        }
    }
}

impl std::fmt::Display for Error {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        let json = serde_json::json!({
            "message": format!("{}", self.kind),
        });
        let s = serde_json::to_string(&json).map_err(|_| std::fmt::Error)?;
        f.write_str(&s)
    }
}

impl From<tokio_postgres::Error> for Error {
    fn from(value: tokio_postgres::Error) -> Self {
        if let Some(e) = value.as_db_error() {
            println!("{}", e);
            match *e.code() {
                SqlState::NO_DATA | SqlState::NO_DATA_FOUND => Self::new(ErrorKind::NotFound),
                _ => Self::new(ErrorKind::Internal),
            }
        } else if let Some(cause) = value.into_source() {
            let mut e = Self::new(ErrorKind::Internal);
            e.inner = Some(cause);
            e
        } else {
            Self::new(ErrorKind::Internal)
        }
    }
}

impl From<deadpool_postgres::PoolError> for Error {
    fn from(_: deadpool_postgres::PoolError) -> Self {
        // TODO add an inner value
        Self::new(ErrorKind::Internal)
    }
}

impl actix_web::error::ResponseError for Error {
    fn status_code(&self) -> actix_web::http::StatusCode {
        use actix_web::http::StatusCode as SC;
        match self.kind {
            ErrorKind::NotFound => SC::NOT_FOUND,
            ErrorKind::TooManyRows => SC::CONFLICT,
            ErrorKind::Internal => SC::INTERNAL_SERVER_ERROR,
        }
    }
    // fn error_response(&self) -> actix_web::HttpResponse<actix_web::body::BoxBody> {
    //     // let r = HttpResponse::build(self.status_code())
    //     //     .content_type("application/json")
    //     //     .body("{}")
    //     //     .map_into_boxed_body();
    //     // r
    //     HttpResponse::build(self.status_code()).json(serde_json::json!({
    //         "the_message": format!("{}", self.kind),
    //     }))
    //     // HttpResponse::with_body(self.status_code(), "testing...".to_string()).map_into_boxed_body()
    // }
}

pub trait Object: Sized {
    fn uid(&self) -> Ulid;
    fn name(&self) -> &str;
    fn get<C: Client>(c: &C, uid: Ulid) -> impl Future<Output = Result<Self, Error>>;
    fn create<C: Client>(&mut self, c: &C) -> impl Future<Output = Result<(), Error>>;
    fn update<C: Client>(&self, c: &C) -> impl Future<Output = Result<(), Error>>;
    fn delete_by_uid<C: Client>(c: &C, uid: Ulid) -> impl Future<Output = Result<(), Error>>;
    /// delete the object.
    fn delete<C: Client>(&self, c: &C) -> impl Future<Output = Result<(), Error>> {
        Self::delete_by_uid(c, self.uid())
    }
}

pub trait TreeObject: Sized {
    fn parents<C: Client>(&self, c: &C) -> impl Future<Output = Result<Vec<Dir>, Error>>;
    fn children<C: Client>(&self, c: &C) -> impl Future<Output = Result<Vec<Self>, Error>>;
}

trait TreeEntry {
    fn set_parent_id(&mut self, id: Ulid);
}

async fn parents<C: Client, O: Object>(c: &C, obj: &O) -> Result<Vec<Dir>, Error> {
    Ok(
        c.query(include_str!("./queries/parent_dirs.sql"), &[&obj.uid()])
            .await?
            .iter()
            .map(|r| {
                Ok(Dir {
                    id: r.try_get(0)?,
                    uid: r.try_get(1)?,
                    name: r.try_get(2)?,
                    description: r.try_get(3)?,
                })
            })
            .collect::<Result<Vec<_>, tokio_postgres::Error>>()?,
    )
}

#[derive(Debug, Serialize, Deserialize, PartialEq)]
pub struct Dir {
    #[serde(skip)]
    pub(crate) id: Id,
    pub(crate) uid: Ulid,
    pub(crate) name: String,
    pub(crate) description: Option<String>,
}

impl Dir {
    pub fn new(uid: Ulid, name: &str) -> Self {
        Self {
            id: 0,
            uid,
            name: name.to_string(),
            description: None,
        }
    }
}

impl Object for Dir {
    fn uid(&self) -> Ulid {
        self.uid
    }

    fn name(&self) -> &str {
        &self.name
    }

    async fn get<C: Client>(c: &C, uid: Ulid) -> Result<Self, Error> {
        let r = query_one(
            c,
            "SELECT id, name, description FROM dir WHERE uid = $1",
            &[&uid],
        )
        .await?;
        Ok(Self {
            uid,
            id: r.try_get("id")?,
            name: r.try_get("name")?,
            description: r.try_get("description")?,
        })
    }

    async fn create<C: Client>(&mut self, c: &C) -> Result<(), Error> {
        let r = query_one(
            c,
            "INSERT INTO dir(uid, name) VALUES ($1, $2) RETURNING id",
            &[&self.uid, &self.name],
        )
        .await?;
        self.id = r.try_get(0)?;
        Ok(())
    }

    async fn update<C: Client>(&self, c: &C) -> Result<(), Error> {
        execute(
            c,
            include_str!("queries/dir_update.sql"),
            &[&self.uid, &self.name, &self.description],
        )
        .await
    }

    async fn delete_by_uid<C: Client>(c: &C, uid: Ulid) -> Result<(), Error> {
        execute(c, "DELETE FROM dir WHERE uid = $1", &[&uid]).await
    }
}

impl TreeObject for Dir {
    async fn parents<C: Client>(&self, c: &C) -> Result<Vec<Dir>, Error> {
        parents(c, self).await
    }

    async fn children<C: Client>(&self, c: &C) -> Result<Vec<Self>, Error> {
        Self::children(c, self.uid).await
    }
}

impl Dir {
    async fn children<C: Client>(c: &C, uid: Ulid) -> Result<Vec<Dir>, Error> {
        Ok(c.query(include_str!("queries/dir_children.sql"), &[&uid])
            .await?
            .iter()
            .map(|r| {
                Ok(Dir {
                    id: r.try_get(0)?,
                    uid: r.try_get(1)?,
                    name: r.try_get(2)?,
                    description: r.try_get(3)?,
                })
            })
            .collect::<Result<Vec<_>, PGError>>()?)
    }
}

#[derive(Debug, Serialize, Deserialize)]
pub struct Entry {
    #[serde(skip)]
    id: Id,
    pub(crate) uid: Ulid,
    pub(crate) href: String,
    pub(crate) name: String,
    pub(crate) description: Option<String>,
    pub(crate) tags: Option<Vec<String>>,
}

impl Entry {
    pub fn new(uid: Ulid, href: &str, name: &str) -> Self {
        Self {
            id: 0,
            uid,
            href: href.to_string(),
            name: name.to_string(),
            description: None,
            tags: None,
        }
    }

    async fn children<C: Client>(c: &C, uid: Ulid) -> Result<Vec<Self>, Error> {
        Ok(c.query(include_str!("queries/entry_children.sql"), &[&uid])
            .await?
            .iter()
            .map(|r| {
                Ok(Self {
                    id: r.try_get(0)?,
                    uid: r.try_get(1)?,
                    href: r.try_get(2)?,
                    name: r.try_get(3)?,
                    description: r.try_get(4)?,
                    tags: None,
                })
            })
            .collect::<Result<Vec<_>, PGError>>()?)
    }

    async fn add_tag<C: Client>(c: &C, uid: Ulid, tag: &str) -> Result<(), Error> {
        execute(c, include_str!("./queries/add_tag.sql"), &[&uid, &tag]).await
    }

    async fn add_tags<C: Client>(c: &C, uid: Ulid, tags: &[String]) -> Result<(), Error> {
        c.execute(include_str!("./queries/add_tags.sql"), &[&uid, &tags])
            .await?;
        Ok(())
    }

    async fn remove_tag<C: Client>(c: &C, uid: Ulid, tag: &str) -> Result<(), Error> {
        execute(
            c,
            include_str!("queries/entry_remove_tag.sql"),
            &[&uid, &tag],
        )
        .await
    }

    #[allow(dead_code)]
    async fn tags_by_uid<C: Client>(c: &C, uid: Ulid) -> Result<Vec<String>, Error> {
        Ok(
            c.query(include_str!("queries/entry_tags_by_uid.sql"), &[&uid])
                .await?
                .iter()
                .map(|r| r.try_get(0))
                .collect::<Result<Vec<String>, PGError>>()?,
        )
    }

    #[allow(dead_code)]
    async fn tags_by_id<C: Client>(c: &C, id: Id) -> Result<Vec<String>, Error> {
        Ok(c.query(
            r#"SELECT tag.name FROM entry_tag et JOIN tag ON (et.tag = tag.id) WHERE et.entry = $1"#,
            &[&id],
        )
        .await?
        .iter()
        .map(|r| r.try_get(0))
        .collect::<Result<Vec<String>, PGError>>()?)
    }

    #[allow(dead_code)]
    pub(crate) async fn tags(&mut self, pool: &Pool) -> Result<&Vec<String>, Error> {
        if let Some(ref tags) = self.tags {
            return Ok(tags);
        }
        let tags = Self::tags_by_id(&pool.get().await?, self.id).await?;
        self.tags = Some(tags);
        Ok(self.tags.as_ref().unwrap())
    }
}

impl TreeObject for Entry {
    #[inline]
    async fn parents<C: Client>(&self, c: &C) -> Result<Vec<Dir>, Error> {
        parents(c, self).await
    }

    #[inline]
    async fn children<C: Client>(&self, c: &C) -> Result<Vec<Self>, Error> {
        Self::children(c, self.uid).await
    }
}

impl Object for Entry {
    fn uid(&self) -> Ulid {
        self.uid
    }

    fn name(&self) -> &str {
        &self.name
    }

    async fn get<C: Client>(c: &C, uid: Ulid) -> Result<Self, Error> {
        let r = query_one(c, include_str!("queries/entry_get.sql"), &[&uid]).await?;
        Ok(Self {
            uid,
            id: r.try_get("id")?,
            href: r.try_get("href")?,
            name: r.try_get("name")?,
            description: r.try_get("description")?,
            tags: r.try_get("tags")?,
        })
    }

    async fn create<C: Client>(&mut self, c: &C) -> Result<(), Error> {
        let r = query_one(
            c,
            include_str!("queries/entry_insert.sql"),
            &[&self.uid, &self.href, &self.name, &self.description],
        )
        .await?;
        self.id = r.try_get(0)?;
        if let Some(ref tags) = self.tags {
            if !tags.is_empty() {
                Self::add_tags(c, self.uid, tags).await?;
            }
        }
        Ok(())
    }

    async fn update<C: Client>(&self, c: &C) -> Result<(), Error> {
        execute(
            c,
            include_str!("queries/entry_update.sql"),
            &[&self.uid, &self.href, &self.name, &self.description],
        )
        .await
    }

    async fn delete_by_uid<C: Client>(c: &C, uid: Ulid) -> Result<(), Error> {
        execute(c, "DELETE FROM entry WHERE uid = $1", &[&uid]).await
    }
}

#[derive(Debug, Serialize, Deserialize)]
pub struct EntryTree {
    entry: Entry,
    parent: Ulid,
}

async fn get_tree<C: Client>(c: &C, base_uid: Ulid) -> Result<(Vec<Dir>, Vec<EntryTree>), Error> {
    use std::collections::vec_deque::VecDeque;
    let mut q = VecDeque::new();
    let mut visited = HashSet::<Ulid>::new();
    q.push_back(base_uid);
    let mut dirs = Vec::new();
    let mut entries = Vec::new();
    while !q.is_empty() {
        let uid = q.pop_front().unwrap();
        if visited.contains(&uid) {
            continue;
        }
        visited.insert(uid);
        let child_dirs = Dir::children(c, uid).await?;
        for d in child_dirs {
            q.push_back(d.uid);
            dirs.push(d);
        }
        let child_entries = Entry::children(c, uid).await?;
        for e in child_entries {
            entries.push(EntryTree {
                entry: e,
                parent: uid,
            });
        }
    }
    Ok((dirs, entries))
}

async fn link_obj<C: Client, O: Object>(c: &C, parent: &Dir, o: &O) -> Result<(), Error> {
    c.execute(
        "INSERT INTO link (uid, parent) VALUES ($1, $2)",
        &[&o.uid(), &parent.uid],
    )
    .await?;
    Ok(())
}

async fn unlink_obj<C: Client, O: Object>(c: &C, o: &O) -> Result<(), Error> {
    c.execute("DELETE FROM link WHERE uid = $1", &[&o.uid()])
        .await?;
    Ok(())
}

pub trait Dao {
    fn create<'a, O: Object>(&self, obj: &'a mut O) -> impl Future<Output = Result<(), Error>>;
    fn get<O: Object>(&self, uid: Ulid) -> impl Future<Output = Result<O, Error>>;
    fn update<O: Object>(&self, o: &O) -> impl Future<Output = Result<(), Error>>;

    fn link<O: Object>(&self, parent: &Dir, o: &O) -> impl Future<Output = Result<(), Error>>;
    fn unlink<O: Object>(&self, o: &O) -> impl Future<Output = Result<(), Error>>;
    fn add_tag(&self, uid: Ulid, tag: &str) -> impl Future<Output = Result<(), Error>>;
    fn add_tags(&self, uid: Ulid, tags: &[String]) -> impl Future<Output = Result<(), Error>>;
    fn remove_tag(&self, uid: Ulid, tag: &str) -> impl Future<Output = Result<(), Error>>;

    fn delete_by_uid<O: Object>(&self, uid: Ulid) -> impl Future<Output = Result<(), Error>>;
    fn delete<O: Object>(&self, o: &O) -> impl Future<Output = Result<(), Error>> {
        self.delete_by_uid::<O>(o.uid())
    }

    /// create and object and link it to the given directory as a child.
    fn create_and_link<'a, 'b, O: Object>(
        &self,
        parent: &'a Dir,
        o: &'b mut O,
    ) -> impl Future<Output = Result<(), Error>> {
        async {
            self.create(o).await.unwrap();
            self.link(parent, o).await?;
            Ok(())
        }
    }
}

pub trait NamedDao {
    fn dir_name_exists<O: Object>(
        &self,
        parent: &Dir,
        o: &O,
    ) -> impl Future<Output = Result<bool, Error>>;
}

pub trait TreeDao {
    fn root_dirs(&self) -> impl Future<Output = Result<Vec<Dir>, Error>>;
    fn tree(&self, uid: Ulid) -> impl Future<Output = Result<(Vec<Dir>, Vec<EntryTree>), Error>>;
    fn children(&self, uid: Ulid) -> impl Future<Output = Result<(Vec<Dir>, Vec<Entry>), Error>>;
    fn child_dirs(&self, uid: Ulid) -> impl Future<Output = Result<Vec<Dir>, Error>>;
    fn child_entries(&self, uid: Ulid) -> impl Future<Output = Result<Vec<Entry>, Error>>;
    fn parents<T: TreeObject>(&self, o: &T) -> impl Future<Output = Result<Vec<Dir>, Error>>;
}

#[derive(Clone)]
pub struct BkDb {
    pool: Pool,
}

impl BkDb {
    #[allow(unused)]
    pub(crate) fn pool(&self) -> &Pool {
        &self.pool
    }
}

impl Dao for BkDb {
    #[inline]
    async fn get<O: Object>(&self, uid: Ulid) -> Result<O, Error> {
        let r = O::get(&self.pool.get().await?, uid).await?;
        Ok(r)
    }
    #[inline]
    async fn create<'a, O: Object>(&self, obj: &'a mut O) -> Result<(), Error> {
        obj.create(&self.pool.get().await?).await
    }
    #[inline]
    async fn delete<O: Object>(&self, o: &O) -> Result<(), Error> {
        o.delete(&self.pool.get().await?).await?;
        Ok(())
    }
    #[inline]
    async fn delete_by_uid<O: Object>(&self, uid: Ulid) -> Result<(), Error> {
        O::delete_by_uid(&self.pool.get().await?, uid).await?;
        Ok(())
    }
    #[inline]
    async fn update<O: Object>(&self, o: &O) -> Result<(), Error> {
        o.update(&self.pool.get().await?).await
    }
    #[inline]
    async fn link<O: Object>(&self, parent: &Dir, o: &O) -> Result<(), Error> {
        link_obj(&self.pool.get().await?, parent, o).await
    }
    #[inline]
    async fn unlink<O: Object>(&self, o: &O) -> Result<(), Error> {
        unlink_obj(&self.pool.get().await?, o).await
    }
    #[inline]
    async fn add_tag(&self, uid: Ulid, tag: &str) -> Result<(), Error> {
        Entry::add_tag(&self.pool.get().await?, uid, tag).await
    }
    #[inline]
    async fn add_tags(&self, uid: Ulid, tags: &[String]) -> Result<(), Error> {
        Entry::add_tags(&self.pool.get().await?, uid, tags).await
    }
    #[inline]
    async fn remove_tag(&self, uid: Ulid, tag: &str) -> Result<(), Error> {
        Entry::remove_tag(&self.pool.get().await?, uid, tag).await
    }
    async fn create_and_link<O: Object>(&self, parent: &Dir, o: &mut O) -> Result<(), Error> {
        let mut c = self.pool.get().await?;
        let tx = c.transaction().await?;
        o.create(&tx).await?;
        link_obj(&tx, parent, o).await?;
        tx.commit().await?;
        Ok(())
    }
}

impl NamedDao for BkDb {
    async fn dir_name_exists<O: Object>(&self, parent: &Dir, o: &O) -> Result<bool, Error> {
        let rows = self
            .pool
            .get()
            .await?
            .query(
                r#"
                SELECT d.uid
                FROM   dir d
                JOIN link l ON (d.uid = l.uid)
                WHERE
                  d.name = $1 AND l.parent = $2
                "#,
                &[&o.name(), &parent.uid],
            )
            .await?;
        Ok(rows.len() > 0)
    }
}

impl BkDb {
    pub fn new(config: deadpool_postgres::Config) -> anyhow::Result<Self> {
        let pool = config.create_pool(
            Some(deadpool_postgres::Runtime::Tokio1),
            tokio_postgres::NoTls,
        )?;
        Ok(Self { pool })
    }

    pub async fn root_dir_exists(&self, dir: &Dir) -> Result<bool, Error> {
        let rows = self
            .pool
            .get()
            .await?
            .query("SELECT uid FROM dir WHERE name = $1", &[&dir.name])
            .await?;
        Ok(rows.len() > 0)
    }
}

impl TreeDao for BkDb {
    async fn root_dirs(&self) -> Result<Vec<Dir>, Error> {
        let rows = self
            .pool
            .get()
            .await?
            .query(include_str!("queries/root_dirs.sql"), &[])
            .await?;
        let res = rows
            .iter()
            .map(|r| {
                let d = Dir {
                    id: r.try_get("id")?,
                    uid: r.try_get("uid")?,
                    name: r.try_get("name")?,
                    description: r.try_get("description")?,
                };
                Ok(d)
            })
            .collect::<Result<Vec<_>, PGError>>()?;
        Ok(res)
    }

    async fn children(&self, uid: Ulid) -> Result<(Vec<Dir>, Vec<Entry>), Error> {
        let rows = self
            .pool
            .get()
            .await?
            .query(include_str!("queries/children.sql"), &[&uid])
            .await?;
        let mut dirs = Vec::new();
        let mut entries = Vec::new();
        for r in rows {
            let is_dir: i32 = r.try_get("is_dir")?;
            if is_dir == 1 {
                dirs.push(Dir {
                    id: r.try_get("id")?,
                    uid: r.try_get("uid")?,
                    name: r.try_get("name")?,
                    description: r.try_get("description")?,
                });
            } else {
                entries.push(Entry {
                    id: r.try_get("id")?,
                    uid: r.try_get("uid")?,
                    name: r.try_get("name")?,
                    description: r.try_get("description")?,
                    href: r.try_get("href")?,
                    tags: None,
                });
            }
        }
        Ok((dirs, entries))
    }

    #[inline]
    async fn tree(&self, uid: Ulid) -> Result<(Vec<Dir>, Vec<EntryTree>), Error> {
        get_tree(&self.pool.get().await?, uid).await
    }

    #[inline]
    async fn child_dirs(&self, uid: Ulid) -> Result<Vec<Dir>, Error> {
        Dir::children(&self.pool.get().await?, uid).await
    }

    #[inline]
    async fn child_entries(&self, uid: Ulid) -> Result<Vec<Entry>, Error> {
        Entry::children(&self.pool.get().await?, uid).await
    }

    #[inline]
    async fn parents<T: TreeObject>(&self, o: &T) -> Result<Vec<Dir>, Error> {
        o.parents(&self.pool.get().await?).await
    }
}

async fn query_one<C, Q>(
    c: &C,
    query: &Q,
    params: &[&(dyn ToSql + Sync)],
) -> Result<tokio_postgres::Row, Error>
where
    C: Client,
    Q: ?Sized + ToStatement + Sync + Send,
{
    use pin_utils::pin_mut;
    let stream = c.query_raw(query, slice_iter(params)).await?;
    pin_mut!(stream);
    let row = match stream.try_next().await? {
        Some(row) => row,
        None => return Err(Error::not_found()),
    };
    if stream.try_next().await?.is_some() {
        return Err(Error::too_many());
    }
    Ok(row)
}

async fn execute<C, Q>(c: &C, query: &Q, params: &[&(dyn ToSql + Sync)]) -> Result<(), Error>
where
    C: Client,
    Q: ?Sized + ToStatement + Sync + Send,
{
    match c.execute(query, params).await? {
        0 => Err(Error::not_found()),
        1 => Ok(()),
        _ => Err(Error::too_many()),
    }
}

fn slice_iter<'a>(
    s: &'a [&'a (dyn ToSql + Sync)],
) -> impl ExactSizeIterator<Item = &'a dyn ToSql> + 'a {
    s.iter().map(|s| *s as _)
}

#[cfg(test)]
mod tests {
    // use super::Dao;
    // struct TestDao;

    #[test]
    fn testing() {
        assert!(true);
    }
}

#[cfg(feature = "functional")]
#[cfg(test)]
mod functional_tests {
    use super::{BkDb, Dao, Dir, Entry, Object, TreeDao};
    use crate::functional_tests::{clear, pg_config};
    use ulid::Ulid;

    fn sort_objs<O: Object>(v: &mut Vec<O>) {
        v.sort_by(|a, b| a.uid().cmp(&b.uid()))
    }

    // #[actix_web::test]
    // #[serial_test::serial]
    // async fn get() -> Result<(), anyhow::Error> {
    //     let dao = BkDb::new(pg_config())?;
    //     clear(&dao.pool).await?;
    //     let uid = Ulid::new();
    //     dao.get::<Dir>(uid).await?;
    //     Ok(())
    // }

    #[actix_web::test]
    #[serial_test::serial]
    async fn test_dir() -> anyhow::Result<()> {
        let dao = BkDb::new(pg_config())?;
        clear(&dao.pool).await?;
        let uid = Ulid::new();
        let mut dir = Dir::new(uid, "test dir");
        dao.create(&mut dir).await?;
        assert!(dir.id != 0);
        dir.name = "directory".to_string();
        dao.update(&dir).await?;
        assert_eq!(dao.get::<Dir>(uid).await?.name, "directory");
        dao.delete(&dir).await?;
        let e = dao.get::<Dir>(uid).await;
        assert!(e.is_err());
        Ok(())
    }

    #[actix_web::test]
    #[serial_test::serial]
    async fn test_entry() {
        let dao = BkDb::new(pg_config()).unwrap();
        clear(&dao.pool).await.unwrap();
        let uid = Ulid::new();
        let mut dir = Dir::new(Ulid::new(), "root");
        let mut entry = Entry::new(uid, "http://google.com", "Google");
        dao.create(&mut dir).await.unwrap();
        dao.create_and_link(&dir, &mut entry).await.unwrap();
        dao.add_tags(entry.uid, &["tools".into(), "web".into(), "z".into()])
            .await
            .unwrap();
        dao.add_tag(entry.uid, "personal-site").await.unwrap();
        assert!(entry.id != 0);
        assert!(dir.id != 0);
        entry.name = "Google Search".to_string();
        entry.href = "https://google.com/".to_string();
        dao.update(&entry).await.unwrap();
        assert_eq!(dao.get::<Entry>(uid).await.unwrap().name, "Google Search");
        assert_eq!(
            dao.get::<Entry>(uid).await.unwrap().href,
            "https://google.com/"
        );
        assert_eq!(
            dao.get::<Entry>(uid).await.unwrap().tags.map(|mut s| {
                s.sort();
                s
            }),
            Some(vec![
                "personal-site".to_string(),
                "tools".to_string(),
                "web".to_string(),
                "z".to_string(),
            ])
        );
        dao.remove_tag(uid, "z").await.unwrap();
        dao.remove_tag(uid, "personal-site").await.unwrap();
        assert_eq!(
            dao.get::<Entry>(uid).await.unwrap().tags,
            Some(vec!["tools".to_string(), "web".to_string(),])
        );
        dao.unlink(&entry).await.unwrap();
        dao.delete(&entry).await.unwrap();
        dao.delete(&dir).await.unwrap();
        let e = dao.get::<Entry>(uid).await;
        assert!(e.is_err());
    }

    #[actix_web::test]
    #[serial_test::serial]
    async fn children() {
        let dao = BkDb::new(pg_config()).unwrap();
        clear(&dao.pool).await.unwrap();
        let mut dir = Dir::new(Ulid::new(), "root");
        dao.create(&mut dir).await.unwrap();
        dao.create_and_link(&dir, &mut Dir::new(Ulid::new(), "a"))
            .await
            .unwrap();
        dao.create_and_link(&dir, &mut Dir::new(Ulid::new(), "b"))
            .await
            .unwrap();
        dao.create_and_link(
            &dir,
            &mut Entry::new(Ulid::new(), "http://hrry.me/", "Harry"),
        )
        .await
        .unwrap();
        dao.create_and_link(
            &dir,
            &mut Entry::new(Ulid::new(), "http://google.com/", "Google"),
        )
        .await
        .unwrap();
        let mut c = Dir::new(Ulid::new(), "c");
        dao.create_and_link(&dir, &mut c).await.unwrap();
        let mut parents = dao.parents(&c).await.unwrap();
        sort_objs(&mut parents);
        assert_eq!(parents.len(), 1);
        assert_eq!(parents[0].uid(), dir.uid());
        assert_eq!(parents[0].id, dir.id);
        assert_eq!(parents[0].name, dir.name);
        let (mut dirs, mut entries) = dao.children(dir.uid).await.unwrap();
        sort_objs(&mut dirs);
        sort_objs(&mut entries);
        assert_eq!(dirs.len(), 3);
        assert_eq!(entries.len(), 2);
        println!("{:?}", entries);
        assert_eq!(entries[0].name, "Harry");
        assert_eq!(entries[1].name, "Google");
        assert_eq!(dirs[0].name, "a");
        assert_eq!(dirs[1].name, "b");
        assert_eq!(dirs[2].name, "c");
        for e in entries {
            dao.unlink(&e).await.unwrap();
            dao.delete(&e).await.unwrap();
        }
        dao.unlink(&c).await.unwrap();
        dao.delete(&c).await.unwrap();
        assert!(dao.get::<Dir>(c.uid).await.is_err());
        clear(&dao.pool).await.unwrap();
    }

    #[actix_web::test]
    #[serial_test::serial]
    async fn update() -> anyhow::Result<()> {
        let dao = BkDb::new(pg_config())?;
        clear(&dao.pool).await.unwrap();
        let mut dir = Dir::new(Ulid::new(), "root");
        dao.create(&mut dir).await?;
        let mut a = Dir::new(Ulid::new(), "a");
        let mut e = Entry::new(Ulid::new(), "t.co", "e");
        dao.create_and_link(&dir, &mut a).await?;
        dao.create_and_link(&dir, &mut e).await?;
        assert_eq!("e", dao.get::<Entry>(e.uid).await?.name);
        e.name = "updated".to_string();
        a.description = Some("a dir".to_string());
        dao.update(&e).await?;
        dao.update(&a).await?;
        assert_eq!("updated", dao.get::<Entry>(e.uid).await?.name);
        assert_eq!(
            Some("a dir".to_string()),
            dao.get::<Dir>(a.uid).await?.description
        );
        Ok(())
    }

    #[actix_web::test]
    #[serial_test::serial]
    async fn tags() -> anyhow::Result<()> {
        let dao = BkDb::new(pg_config())?;
        clear(&dao.pool).await.unwrap();
        let mut dir = Dir::new(Ulid::new(), "root");
        dao.create(&mut dir).await?;
        Ok(())
    }

    // #[actix_web::test]
    // #[serial_test::serial]
    // async fn not_found() -> anyhow::Result<()> {
    //     let db = BkDb::new(pg_config())?;
    //     let uid = Ulid::new();
    //     let mut d0 = Dir::new(uid, "test-dir0");
    //     let mut d1 = Dir::new(uid, "test-dir1");
    //     db.create(&mut d0).await?;
    //     db.create(&mut d1).await?;
    //     Ok(())
    // }
}
