"""Echo gRPC server implementation."""

from __future__ import annotations

import argparse
import signal
import time
from collections.abc import Iterator
from concurrent import futures
from datetime import datetime, timezone
from types import FrameType

import grpc
from demo.echo.v1 import echo_pb2, echo_pb2_grpc


class EchoServiceServicer(echo_pb2_grpc.EchoServiceServicer):
    """Implementation of the EchoService."""

    def Echo(
        self,
        request: echo_pb2.EchoRequest,
        context: grpc.ServicerContext,
    ) -> echo_pb2.EchoResponse:
        timestamp = datetime.now(timezone.utc).isoformat()
        return echo_pb2.EchoResponse(
            message=request.message,
            timestamp=timestamp,
        )

    def EchoStream(
        self,
        request: echo_pb2.EchoStreamRequest,
        context: grpc.ServicerContext,
    ) -> Iterator[echo_pb2.EchoResponse]:
        for _ in range(request.repeat_count):
            timestamp = datetime.now(timezone.utc).isoformat()
            yield echo_pb2.EchoResponse(
                message=request.message,
                timestamp=timestamp,
            )
            time.sleep(0.1)


def serve(port: int) -> None:
    server = grpc.server(futures.ThreadPoolExecutor(max_workers=4))
    echo_pb2_grpc.add_EchoServiceServicer_to_server(
        EchoServiceServicer(), server
    )
    server.add_insecure_port(f"[::]:{port}")
    server.start()
    print(f"Echo server listening on port {port}")

    def shutdown(signum: int, frame: FrameType | None) -> None:
        print("\nShutting down...")
        server.stop(grace=2)

    signal.signal(signal.SIGINT, shutdown)
    signal.signal(signal.SIGTERM, shutdown)

    server.wait_for_termination()


def main() -> None:
    parser = argparse.ArgumentParser(description="Echo gRPC server")
    parser.add_argument(
        "--port", type=int, default=50051, help="Port to listen on"
    )
    args = parser.parse_args()
    serve(args.port)


if __name__ == "__main__":
    main()
