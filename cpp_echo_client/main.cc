#include <iostream>
#include <memory>
#include <string>

#include <grpcpp/grpcpp.h>

#include "demo/echo/v1/echo.grpc.pb.h"

int main(int argc, char** argv) {
    std::string host = "localhost";
    int port = 50053;
    std::string message;

    for (int i = 1; i < argc; i++) {
        std::string arg(argv[i]);
        if (arg == "--host" && i + 1 < argc) {
            host = argv[++i];
        } else if (arg == "--port" && i + 1 < argc) {
            port = std::stoi(argv[++i]);
        } else if (message.empty()) {
            message = arg;
        }
    }

    if (message.empty()) {
        std::cerr << "Usage: cpp_echo_client [--host HOST] [--port PORT] <message>" << std::endl;
        return 1;
    }

    std::string target = host + ":" + std::to_string(port);
    auto channel = grpc::CreateChannel(target, grpc::InsecureChannelCredentials());
    auto stub = demo::echo::v1::EchoService::NewStub(channel);

    demo::echo::v1::EchoRequest request;
    request.set_message(message);

    demo::echo::v1::EchoResponse response;
    grpc::ClientContext context;

    grpc::Status status = stub->Echo(&context, request, &response);
    if (!status.ok()) {
        std::cerr << "RPC failed: " << status.error_message() << std::endl;
        return 1;
    }

    std::cout << "Response: " << response.message() << std::endl;
    std::cout << "Timestamp: " << response.timestamp() << std::endl;
    return 0;
}
