use clap::Args;

// creates a module called 'migratinos' using the files in './migrations'
refinery::embed_migrations!("migrations");

#[derive(Args, Debug)]
pub struct Cmd {
    /// The target version number to run.
    ///
    /// Files named 'V1__*.sql' have a target of 1, 'V2__*.sql' have a target of 2.
    #[arg(short, long)]
    target: Option<i32>,
    /// Run the 'down' migration scripts to rollback the database.
    #[arg(short, long, default_value_t = false)]
    down: bool,
    #[arg(long)]
    list: bool,
}

type Error = Box<dyn std::error::Error + Send + Sync + 'static>;

impl Cmd {
    pub async fn run(
        &self,
        config: &tokio_postgres::Config,
    ) -> Result<(), Box<dyn std::error::Error + Send + Sync + 'static>> {
        let runner = migrations::runner();
        if self.list {
            for migration in runner.get_migrations() {
                println!(
                    "name: {}, version: {} -- {:?}",
                    migration.name(),
                    migration.version(),
                    migration
                );
            }
            return Ok(());
        }
        log::info!(
            user = config.get_user(),
            dbname = config.get_dbname();
            "connecting to postgres"
        );
        let (mut client, con) = config.connect(tokio_postgres::NoTls).await?;
        tokio::spawn(async move {
            if let Err(e) = con.await {
                eprintln!("connection error: {}", e);
            }
        });
        log::info!("database connection success");
        runner.run_async(&mut client).await?;
        log::info!("migration succeeded");
        Ok(())
    }
}

pub async fn drop(config: &tokio_postgres::Config) -> Result<(), Error> {
    let (client, con) = config.connect(tokio_postgres::NoTls).await?;
    tokio::spawn(async move {
        if let Err(e) = con.await {
            eprintln!("connection error: {}", e);
        }
    });
    for tbl in &[
        "entry_tag",
        "tag",
        "link",
        "entry",
        "dir",
        "refinery_schema_history",
    ] {
        let q = format!("DROP TABLE {}", tbl);
        let res = client.simple_query(&q).await;
        if res.is_err() {
            log::error!("failed to drop {tbl:?}: {}", res.unwrap_err());
        }
    }
    Ok(())
}
