use std::pin::Pin;

use clap::Parser;
use tokio::sync::mpsc;
use tokio_stream::wrappers::ReceiverStream;
use tonic::{transport::Server, Request, Response, Status};

use rust_package::demo::echo::v1::echo_service_server::{EchoService, EchoServiceServer};
use rust_package::demo::echo::v1::{EchoRequest, EchoResponse, EchoStreamRequest};

#[derive(Parser)]
#[command(about = "Echo gRPC server")]
struct Args {
    #[arg(long, default_value_t = 50054)]
    port: u16,
}

#[derive(Default)]
struct EchoServiceImpl;

#[tonic::async_trait]
impl EchoService for EchoServiceImpl {
    async fn echo(&self, request: Request<EchoRequest>) -> Result<Response<EchoResponse>, Status> {
        let req = request.into_inner();
        let timestamp = chrono_now();
        Ok(Response::new(EchoResponse {
            message: req.message,
            timestamp,
        }))
    }

    type EchoStreamStream =
        Pin<Box<dyn tokio_stream::Stream<Item = Result<EchoResponse, Status>> + Send>>;

    async fn echo_stream(
        &self,
        request: Request<EchoStreamRequest>,
    ) -> Result<Response<Self::EchoStreamStream>, Status> {
        let req = request.into_inner();
        let (tx, rx) = mpsc::channel(32);

        tokio::spawn(async move {
            for _ in 0..req.repeat_count {
                let resp = EchoResponse {
                    message: req.message.clone(),
                    timestamp: chrono_now(),
                };
                if tx.send(Ok(resp)).await.is_err() {
                    break;
                }
                tokio::time::sleep(std::time::Duration::from_millis(100)).await;
            }
        });

        Ok(Response::new(Box::pin(ReceiverStream::new(rx))))
    }
}

fn chrono_now() -> String {
    let now = std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .unwrap()
        .as_secs();
    // Simple ISO 8601 without external chrono crate
    let secs_per_day = 86400u64;
    let days = now / secs_per_day;
    let day_secs = now % secs_per_day;
    let hours = day_secs / 3600;
    let minutes = (day_secs % 3600) / 60;
    let seconds = day_secs % 60;

    // Days since epoch to date (simplified)
    let mut y = 1970i64;
    let mut remaining_days = days as i64;
    loop {
        let days_in_year = if is_leap(y) { 366 } else { 365 };
        if remaining_days < days_in_year {
            break;
        }
        remaining_days -= days_in_year;
        y += 1;
    }
    let month_days: [i64; 12] = if is_leap(y) {
        [31, 29, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]
    } else {
        [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]
    };
    let mut m = 0usize;
    for (i, &md) in month_days.iter().enumerate() {
        if remaining_days < md {
            m = i;
            break;
        }
        remaining_days -= md;
    }

    format!(
        "{:04}-{:02}-{:02}T{:02}:{:02}:{:02}Z",
        y,
        m + 1,
        remaining_days + 1,
        hours,
        minutes,
        seconds
    )
}

fn is_leap(y: i64) -> bool {
    (y % 4 == 0 && y % 100 != 0) || y % 400 == 0
}

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    let args = Args::parse();
    let addr = format!("0.0.0.0:{}", args.port).parse()?;

    println!("Echo server listening on port {}", args.port);

    Server::builder()
        .add_service(EchoServiceServer::new(EchoServiceImpl))
        .serve_with_shutdown(addr, async {
            tokio::signal::ctrl_c().await.ok();
            println!("\nShutting down...");
        })
        .await?;

    Ok(())
}
