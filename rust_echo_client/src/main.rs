use clap::Parser;
use tonic::Request;

use rust_package::demo::echo::v1::echo_service_client::EchoServiceClient;
use rust_package::demo::echo::v1::EchoRequest;

#[derive(Parser)]
#[command(about = "Echo gRPC client")]
struct Args {
    message: String,

    #[arg(long, default_value = "localhost")]
    host: String,

    #[arg(long, default_value_t = 50054)]
    port: u16,
}

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    let args = Args::parse();
    let target = format!("http://{}:{}", args.host, args.port);

    let mut client = EchoServiceClient::connect(target).await?;

    let request = Request::new(EchoRequest {
        message: args.message,
    });

    let response = client.echo(request).await?;
    let resp = response.into_inner();

    println!("Response: {}", resp.message);
    println!("Timestamp: {}", resp.timestamp);

    Ok(())
}
