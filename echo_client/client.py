"""Echo gRPC client."""

from __future__ import annotations

import argparse

import grpc
from demo.echo.v1 import echo_pb2, echo_pb2_grpc


def main() -> None:
    parser = argparse.ArgumentParser(description="Echo gRPC client")
    parser.add_argument("message", help="Message to echo")
    parser.add_argument("--host", default="localhost", help="Server host")
    parser.add_argument("--port", type=int, default=50051, help="Server port")
    args = parser.parse_args()

    target = f"{args.host}:{args.port}"
    with grpc.insecure_channel(target) as channel:
        stub = echo_pb2_grpc.EchoServiceStub(channel)
        request = echo_pb2.EchoRequest(message=args.message)
        response = stub.Echo(request)
        print(f"Response: {response.message}")
        print(f"Timestamp: {response.timestamp}")


if __name__ == "__main__":
    main()
