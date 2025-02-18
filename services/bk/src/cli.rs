use clap::{Args, Parser, Subcommand};

use super::migrate;

#[derive(Parser)]
#[command(author, version, about, long_about = None)]
pub struct Cli {
    #[command(subcommand)]
    pub command: Command,
    #[arg(long, env = "BK_DB_URL")]
    pub db_url: Option<String>,
    #[arg(long, env = "BK_DB_USER", default_value = "bk")]
    pub db_user: String,
    #[arg(long, env = "BK_DB_HOST", default_value = "127.0.0.1")]
    pub db_host: String,
    #[arg(long, env = "BK_DB_PORT", default_value_t = 5432)]
    pub db_port: u16,
    #[arg(long, env = "BK_DB_PASSWORD", default_value = "testbed08")]
    db_password: String,
    #[arg(long, env = "BK_DB_NAME", default_value = "bk")]
    pub db_name: String,
    #[arg(long, env = "BK_SSL")]
    pub db_ssl: bool,
    #[arg(long, short, env = "BK_LOG_LEVEL", default_value_t = log::Level::Info)]
    pub(crate) log_level: log::Level,
    #[arg(long, env = "BK_LOG_FORMAT", default_value_t = flog::Format::LogFmt)]
    pub(crate) log_format: flog::Format,
}

impl Cli {
    pub fn pg_config(&self) -> tokio_postgres::Config {
        use tokio_postgres::config::SslMode;
        if let Some(ref u) = self.db_url {
            u.parse::<tokio_postgres::Config>().unwrap()
        } else {
            let mut c = tokio_postgres::Config::new();
            c.application_name("bk")
                .host(&self.db_host)
                .port(self.db_port)
                .dbname(&self.db_name)
                .user(&self.db_user)
                .password(&self.db_password)
                .ssl_mode(SslMode::Disable)
                .connect_timeout(core::time::Duration::new(10, 0))
                .tcp_user_timeout(core::time::Duration::new(10, 0));
            if self.db_ssl {
                c.ssl_mode(SslMode::Prefer);
            }
            c
        }
    }

    pub fn pool_config(&self) -> deadpool_postgres::Config {
        let mut c = deadpool_postgres::Config::new();
        c.host = Some(self.db_host.clone());
        c.port = Some(self.db_port);
        c.dbname = Some(self.db_name.clone());
        c.user = Some(self.db_user.clone());
        c.password = Some(self.db_password.clone());
        if self.db_ssl {
            c.ssl_mode = Some(deadpool_postgres::SslMode::Prefer);
        }
        c
    }
}

#[derive(Subcommand, Debug)]
#[command(author = "")]
pub enum Command {
    /// Run the server.
    Server(Server),
    /// Run database migrations.
    Migrate(migrate::Cmd),
    /// Drop all tables owned by the current user.
    Drop,
    /// Import bookmarks from a local browser.
    Import { target: crate::import::Browser },
    #[command(hide = true)]
    Test,
}

#[derive(Args, Debug)]
pub struct Server {
    #[arg(long, short = 'H', default_value = "0.0.0.0", env)]
    pub host: String,
    #[arg(long, short, default_value_t = 8089, env)]
    pub port: u16,
    /// Number of worker threads
    #[arg(short, long, default_value_t = 6, env = "SERVER_WORKERS")]
    pub workers: usize,
}
