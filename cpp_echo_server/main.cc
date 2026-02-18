#include <atomic>
#include <chrono>
#include <csignal>
#include <ctime>
#include <iostream>
#include <memory>
#include <string>
#include <thread>

#include <grpcpp/grpcpp.h>

#include "demo/echo/v1/echo.grpc.pb.h"

class EchoServiceImpl final : public demo::echo::v1::EchoService::Service {
public:
    grpc::Status Echo(grpc::ServerContext* /*context*/,
                      const demo::echo::v1::EchoRequest* request,
                      demo::echo::v1::EchoResponse* response) override {
        response->set_message(request->message());
        response->set_timestamp(now_iso8601());
        return grpc::Status::OK;
    }

    grpc::Status EchoStream(
            grpc::ServerContext* /*context*/,
            const demo::echo::v1::EchoStreamRequest* request,
            grpc::ServerWriter<demo::echo::v1::EchoResponse>* writer) override {
        for (int i = 0; i < request->repeat_count(); i++) {
            demo::echo::v1::EchoResponse response;
            response.set_message(request->message());
            response.set_timestamp(now_iso8601());
            writer->Write(response);
            std::this_thread::sleep_for(std::chrono::milliseconds(100));
        }
        return grpc::Status::OK;
    }

private:
    static std::string now_iso8601() {
        auto now = std::chrono::system_clock::now();
        auto time_t = std::chrono::system_clock::to_time_t(now);
        char buf[64];
        std::strftime(buf, sizeof(buf), "%Y-%m-%dT%H:%M:%SZ", std::gmtime(&time_t));
        return buf;
    }
};

static std::atomic<bool> g_shutdown{false};

static void shutdown_handler(int /*signum*/) {
    g_shutdown.store(true);
}

int main(int argc, char** argv) {
    int port = 50053;
    for (int i = 1; i < argc; i++) {
        std::string arg(argv[i]);
        if (arg == "--port" && i + 1 < argc) {
            port = std::stoi(argv[++i]);
        }
    }

    std::string server_address = "0.0.0.0:" + std::to_string(port);

    EchoServiceImpl service;
    grpc::ServerBuilder builder;
    builder.AddListeningPort(server_address, grpc::InsecureServerCredentials());
    builder.RegisterService(&service);

    auto server = builder.BuildAndStart();
    std::cout << "Echo server listening on port " << port << std::endl;

    std::signal(SIGINT, shutdown_handler);
    std::signal(SIGTERM, shutdown_handler);

    // Poll for shutdown signal to avoid calling Shutdown() from signal handler
    while (!g_shutdown.load()) {
        std::this_thread::sleep_for(std::chrono::milliseconds(100));
    }
    std::cout << "\nShutting down..." << std::endl;
    server->Shutdown();
    return 0;
}
