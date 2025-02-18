use std::env;
use std::path::PathBuf;

use serde::Serialize;

#[derive(Serialize, Debug, Clone, clap::ValueEnum)]
pub enum Browser {
    Chromium,
    Chrome,
    Brave,
    Firefox,
}

pub fn find_bookmarks_file(browser: Browser) -> Option<PathBuf> {
    let xdg = env::var("XDG_CONFIG_HOME").ok()?;
    match browser {
        Browser::Brave => Some(
            [
                &xdg,
                "BraveSoftware",
                "Brave-Browser",
                "Default",
                "Bookmarks",
            ]
            .iter()
            .collect(),
        ),
        Browser::Chrome => Some(
            [&xdg, "google-chrome", "Default", "Bookmarks"]
                .iter()
                .collect(),
        ),
        Browser::Chromium => {
            let home = env::var("HOME").ok()?;
            let paths: Vec<PathBuf> = vec![
                [
                    &home,
                    "snap",
                    "chromium",
                    "common",
                    "chromium",
                    "Default",
                    "Bookmarks",
                ]
                .iter()
                .collect(),
                [&xdg, "chromium", "Default", "Bookmarks"].iter().collect(),
            ];
            for p in paths {
                if p.exists() {
                    return Some(p);
                }
            }
            None
        }
        Browser::Firefox => None,
    }
}

pub mod chrome {
    use futures::future::{FutureExt, LocalBoxFuture};
    use serde_derive::Deserialize;
    use serde_derive::Serialize;
    use std::collections::HashMap;
    use ulid::Ulid;

    use crate::dao::{BkDb, NamedDao};
    use crate::dao::{Dao, Dir, Entry, Object};

    #[derive(Default, Debug, Clone, PartialEq, Serialize, Deserialize)]
    #[serde(rename_all = "camelCase")]
    pub struct Bookmarks {
        pub checksum: String,
        pub roots: HashMap<String, Bookmark>,
        pub version: i64,
        #[serde(rename = "sync_metadata")]
        pub sync_metadata: String,
    }

    #[derive(Default, Debug, Clone, PartialEq, Serialize, Deserialize)]
    pub enum BookmarkType {
        #[default]
        #[serde(rename = "folder")]
        Folder,
        #[serde(rename = "url")]
        Url,
    }

    #[derive(Default, Debug, Clone, PartialEq, Serialize, Deserialize)]
    #[serde(rename_all = "camelCase")]
    pub struct Bookmark {
        pub id: String,
        pub guid: String,
        pub name: String,
        pub url: Option<String>,
        #[serde(rename = "date_added")]
        pub date_added: String,
        #[serde(rename = "date_last_used")]
        pub date_last_used: String,
        #[serde(rename = "date_modified")]
        pub date_modified: Option<String>,
        #[serde(rename = "type")]
        pub type_field: BookmarkType,
        pub children: Option<Vec<Bookmark>>,
        #[serde(rename = "meta_info")]
        pub meta_info: Option<MetaInfo>,
    }

    #[derive(Default, Debug, Clone, PartialEq, Serialize, Deserialize)]
    #[serde(rename_all = "camelCase")]
    pub struct MetaInfo {
        #[serde(rename = "power_bookmark_meta")]
        pub power_bookmark_meta: String,
    }

    pub async fn load(dao: &BkDb, bookmarks: &Bookmarks) -> anyhow::Result<()> {
        let mut dir = Dir::new(
            Ulid::new(),
            &format!("imported from chromium {}", bookmarks.checksum),
        );
        if !dao.root_dir_exists(&dir).await? {
            dao.create(&mut dir).await?;
        }
        for (_, bk) in bookmarks.roots.iter() {
            load_bookmark(dao, &dir, &bk, 0).await?;
        }
        Ok(())
    }

    fn load_bookmark<'a>(
        dao: &'a BkDb,
        parent: &'a Dir,
        bk: &'a Bookmark,
        depth: u32,
    ) -> LocalBoxFuture<'a, Result<(), anyhow::Error>> {
        async move {
            match bk.type_field {
                BookmarkType::Url => {
                    let url = bk.url.as_ref().unwrap();
                    let mut e = Entry::new(Ulid::new(), &url, &bk.name);
                    log::info!(
                        target: "import",
                        url,
                        name=bk.name,
                        parent=parent.name();
                        "add bookmark");
                    dao.create_and_link(parent, &mut e).await?;
                }
                BookmarkType::Folder => {
                    let mut dir = Dir::new(Ulid::new(), &bk.name);
                    if !dao.dir_name_exists(&parent, &dir).await? {
                        log::info!(
                            target: "import",
                            uid=dir.uid().to_string(),
                            name=bk.name,
                            parent=parent.name();
                            "add folder");
                        dao.create_and_link(&parent, &mut dir).await?;
                    }
                    let d = depth + 1;
                    if let Some(ref children) = bk.children {
                        for c in children {
                            load_bookmark(dao, &dir, &c, d).await?;
                        }
                    }
                }
            };
            Ok(())
        }
        .boxed_local()
    }
}
