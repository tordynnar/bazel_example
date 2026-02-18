package main

import (
	"context"
	"flag"
	"fmt"
	"log"
	"net"
	"os"
	"os/signal"
	"syscall"
	"time"

	"google.golang.org/grpc"

	echov1 "github.com/bazel_test/go_package/demo/echo/v1"
)

type echoServer struct {
	echov1.UnimplementedEchoServiceServer
}

func (s *echoServer) Echo(_ context.Context, req *echov1.EchoRequest) (*echov1.EchoResponse, error) {
	return &echov1.EchoResponse{
		Message:   req.Message,
		Timestamp: time.Now().UTC().Format(time.RFC3339),
	}, nil
}

func (s *echoServer) EchoStream(req *echov1.EchoStreamRequest, stream echov1.EchoService_EchoStreamServer) error {
	for i := int32(0); i < req.RepeatCount; i++ {
		if err := stream.Send(&echov1.EchoResponse{
			Message:   req.Message,
			Timestamp: time.Now().UTC().Format(time.RFC3339),
		}); err != nil {
			return err
		}
		time.Sleep(100 * time.Millisecond)
	}
	return nil
}

func main() {
	port := flag.Int("port", 50052, "Port to listen on")
	flag.Parse()

	lis, err := net.Listen("tcp", fmt.Sprintf(":%d", *port))
	if err != nil {
		log.Fatalf("failed to listen: %v", err)
	}

	s := grpc.NewServer()
	echov1.RegisterEchoServiceServer(s, &echoServer{})

	sigCh := make(chan os.Signal, 1)
	signal.Notify(sigCh, syscall.SIGINT, syscall.SIGTERM)
	go func() {
		<-sigCh
		fmt.Println("\nShutting down...")
		s.GracefulStop()
	}()

	fmt.Printf("Echo server listening on port %d\n", *port)
	if err := s.Serve(lis); err != nil {
		log.Fatalf("failed to serve: %v", err)
	}
}
