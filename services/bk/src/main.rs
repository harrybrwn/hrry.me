mod cli;
mod dao;
mod error;
mod import;
mod migrate;
mod server;

use cli::{Cli, Command, Server};
use dao::BkDb;
use server::configure;

use clap::Parser;

async fn server(cli: &Cli, server: &Server) -> anyhow::Result<()> {
    use actix_web::{App, HttpServer};
    let dao = BkDb::new(cli.pool_config())?;
    let host = server.host.clone();
    let port = server.port;
    log::debug!(
        host, port, workers = server.workers;
        "running server \"{host}:{port}\" using {workers} workers",
        workers = server.workers
    );
    HttpServer::new(move || {
        App::new()
            .wrap(actix_request_logger::RequestLogger)
            .configure(configure(dao.clone()))
    })
    .workers(server.workers)
    .bind((server.host.clone(), server.port))?
    .run()
    .await?;
    Ok(())
}

#[actix_web::main]
async fn main() -> Result<(), Box<dyn std::error::Error + Send + Sync + 'static>> {
    let cli = Cli::parse();
    flog::Config::new()
        .format(cli.log_format)
        .level(cli.log_level)
        .load_env()
        .init()?;
    match cli.command {
        Command::Server(ref s) => {
            server(&cli, s).await?;
        }
        Command::Migrate(ref migration) => {
            let conf = cli.pg_config();
            migration.run(&conf).await?;
        }
        Command::Drop => {
            migrate::drop(&cli.pg_config()).await?;
        }
        Command::Import { ref target } => {
            use import::Browser;
            let p = import::find_bookmarks_file(target.clone()).ok_or(anyhow::anyhow!(
                "failed to find browser spesific bookmarks file"
            ))?;
            let mut f = std::fs::File::open(p)?;
            let dao = BkDb::new(cli.pool_config())?;
            match target {
                Browser::Chrome | Browser::Brave => {
                    let b: import::chrome::Bookmarks = serde_json::from_reader(&mut f)?;
                    import::chrome::load(&dao, &b).await?;
                }
                _ => return Err(anyhow::anyhow!("can't load that browser type").into()),
            };
        }
        Command::Test => {}
    }
    Ok(())
}

#[cfg(test)]
mod tests {
    #[test]
    fn bookmarks() {}
}

#[cfg(feature = "functional")]
#[cfg(test)]
mod functional_tests {
    use actix_web::{
        http::header::Accept,
        test::{self, TestRequest},
        App,
    };
    use serde_json::json;
    use ulid::Ulid;

    use crate::dao::{self, BkDb, Dao, Entry, Object};
    use crate::server::configure;

    pub fn pg_config() -> deadpool_postgres::Config {
        let mut c = deadpool_postgres::Config::new();
        c.user = Some("bk".to_string());
        c.password = Some("testbed08".to_string());
        c.host = Some("localhost".to_string());
        c.dbname = Some("bk".to_string());
        c
    }

    pub async fn clear(p: &deadpool_postgres::Pool) -> Result<(), deadpool_postgres::PoolError> {
        let mut c = p.get().await?;
        let tx = c.transaction().await?;
        tx.simple_query("DELETE FROM link").await?;
        tx.simple_query("DELETE FROM entry").await?;
        tx.simple_query("DELETE FROM dir").await?;
        tx.commit().await?;
        Ok(())
    }

    #[actix_web::test]
    #[serial_test::serial]
    async fn roots() {
        let db = BkDb::new(pg_config()).unwrap();
        let app = test::init_service(
            App::new()
                .wrap(actix_request_logger::RequestLogger)
                .configure(configure(db.clone())),
        )
        .await;
        clear(db.pool()).await.unwrap();
        let mut dir = dao::Dir::new(Ulid::new(), "test-dir");
        db.create(&mut dir).await.unwrap();
        let req = TestRequest::get()
            .uri("/roots")
            .insert_header(Accept::json())
            .to_request();
        let res: Vec<dao::Dir> = test::call_and_read_body_json(&app, req).await;
        assert_eq!(res.len(), 1);
        assert_eq!(res[0].id, 0); // responses should not return the internal ID
        assert_eq!(res[0].uid, dir.uid);
        assert_eq!(res[0].name, dir.name);
        assert_eq!(res[0].description, dir.description);
        db.delete(&dir).await.unwrap();
    }

    #[actix_web::test]
    #[serial_test::serial]
    async fn get_bookmark() -> anyhow::Result<()> {
        let db = BkDb::new(pg_config())?;
        let app = test::init_service(
            App::new()
                .wrap(actix_request_logger::RequestLogger)
                .configure(configure(db.clone())),
        )
        .await;
        clear(db.pool()).await?;
        let mut dir = dao::Dir::new(Ulid::new(), "test-dir");
        let mut e = Entry::new(Ulid::new(), "https://theoldnet.com", "The Old Net");
        db.create(&mut dir).await?;
        db.create_and_link(&dir, &mut e).await?;
        let req = TestRequest::get()
            .uri(&format!("/bookmark/{}", e.uid))
            .to_request();
        let res: dao::Entry = test::call_and_read_body_json(&app, req).await;
        assert_eq!(res.uid, e.uid);
        assert_eq!(res.name, e.name);
        assert_eq!(res.href, e.href);
        assert_eq!(res.description, e.description);
        Ok(())
    }

    #[actix_web::test]
    #[serial_test::serial]
    async fn add_bookmark() -> anyhow::Result<()> {
        let db = BkDb::new(pg_config())?;
        let app = test::init_service(
            App::new()
                .wrap(actix_request_logger::RequestLogger)
                .configure(configure(db.clone())),
        )
        .await;
        clear(db.pool()).await?;
        let mut dir = dao::Dir::new(Ulid::new(), "test-dir");
        db.create(&mut dir).await?;
        let req = TestRequest::post()
            .uri("/bookmark")
            .set_json(json!({
                "href": "https://theoldnet.com",
                "name": "The Old Net",
                "tags": [
                    "90s",
                    "web",
                ],
            }))
            .to_request();
        let res: dao::Entry = test::call_and_read_body_json(&app, req).await;
        let new_entry: dao::Entry = db.get(res.uid()).await?;
        assert_eq!(res.uid, new_entry.uid);
        assert_eq!(res.name, new_entry.name);
        assert_eq!(res.href, new_entry.href);
        assert_eq!(res.tags, new_entry.tags);
        assert_eq!(res.name, "The Old Net");
        assert_eq!(res.href, "https://theoldnet.com");
        assert_eq!(res.tags, Some(vec!["90s".into(), "web".into()]));
        let resp = test::call_service(
            &app,
            TestRequest::get()
                .uri(&format!("/bookmark/{}", Ulid::new()))
                .to_request(),
        )
        .await;
        assert_eq!(resp.status(), actix_web::http::StatusCode::NOT_FOUND);
        Ok(())
    }

    #[actix_web::test]
    #[serial_test::serial]
    async fn get_children() -> anyhow::Result<()> {
        let db = BkDb::new(pg_config())?;
        let app = test::init_service(App::new().configure(configure(db.clone()))).await;
        clear(db.pool()).await?;
        let mut root = dao::Dir::new(Ulid::new(), "root");
        db.create(&mut root).await?;
        println!("{:#?}", root);
        Ok(())
    }

    // #[actix_web::test]
    // #[serial_test::serial]
    // async fn test() -> anyhow::Result<()> {
    //     Ok(())
    // }

    // #[actix_web::test]
    // #[serial_test::serial]
    // async fn test() -> anyhow::Result<()> {
    //     Ok(())
    // }
}
