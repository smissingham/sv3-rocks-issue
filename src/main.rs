use std::env;

use anyhow::Result;
use surrealdb::engine::local::RocksDb;
use surrealdb::Surreal;

#[tokio::main]
async fn main() -> Result<()> {
    let db_path = env::var("REPRO_DB_PATH").unwrap_or_else(|_| "./db".to_string());

    eprintln!("[repro] opening rocksdb at {db_path}");
    let db = Surreal::new::<RocksDb>(db_path).await?;

    eprintln!("[repro] selecting namespace and database");
    db.use_ns("repro").use_db("repro").await?;

    eprintln!("READY");
    tokio::signal::ctrl_c().await?;
    eprintln!("SHUTDOWN");

    Ok(())
}
