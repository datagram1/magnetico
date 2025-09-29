package dht

import (
	"fmt"
	"math/rand/v2"
	"net"
	"reflect"
	"strconv"
	"testing"
	"time"

	"tgragnato.it/magnetico/v2/dht/mainline"
)

const (
	ChanSize       = 20
	MaxNeighbours  = 10
	ManagerAddress = "127.0.0.1"
	PeerIP         = "192.168.1.1"
	DefaultTimeOut = time.Second
)

type TestResult struct {
	infoHash  [20]byte
	peerAddrs []net.TCPAddr
}

func (tr *TestResult) InfoHash() [20]byte {
	return tr.infoHash
}

func (tr *TestResult) PeerAddrs() []net.TCPAddr {
	return tr.peerAddrs
}

func TestChannelOutput(t *testing.T) {
	t.Parallel()

	address := ManagerAddress + ":" + strconv.Itoa(rand.IntN(64511)+1024)
	manager := NewManager([]string{address}, MaxNeighbours, []string{"dht.tgragnato.it"}, []net.IPNet{})
	peerPort := rand.IntN(64511) + 1024

	result := &TestResult{
		infoHash: [20]byte{255},
		peerAddrs: []net.TCPAddr{{
			IP:   net.ParseIP(PeerIP),
			Port: peerPort,
		}},
	}
	outputChan := make(chan Result, ChanSize)
	manager.output = outputChan
	manager.output <- result

	receivedResult := <-outputChan
	if !reflect.DeepEqual(receivedResult, result) {
		t.Errorf("\nReceived result %v, \nExpected result %v", receivedResult, result)
	}

	manager.Terminate()
}

func TestOnIndexingResult(t *testing.T) {
	t.Parallel()

	address := ManagerAddress + ":" + strconv.Itoa(rand.IntN(64511)+1024)
	manager := NewManager([]string{address}, MaxNeighbours, []string{"dht.tgragnato.it"}, []net.IPNet{})

	result := mainline.IndexingResult{}
	outputChan := make(chan Result, ChanSize)
	manager.output = outputChan

	for i := 0; i < ChanSize; i++ {
		manager.onIndexingResult(result)
	}

	// Verify that the result is sent to the output channel
	select {
	case receivedResult := <-outputChan:
		if !reflect.DeepEqual(receivedResult, result) {
			t.Errorf("\nReceived result %v, \nExpected result %v", receivedResult, result)
		}
	default:
		t.Error("Expected result not received")
	}

	manager.Terminate()
}

func TestManagerOutput(t *testing.T) {
	t.Parallel()

	// Use a different port to avoid conflicts
	port := 6881 + rand.IntN(1000)
	addr := fmt.Sprintf("127.0.0.1:%d", port)
	
	manager := NewManager([]string{addr}, 10, []string{addr}, nil)
	defer manager.Terminate()

	// Test that Output() returns a channel
	outputChan := manager.Output()
	if outputChan == nil {
		t.Error("Output() should return a non-nil channel")
	}
}

func TestManagerOnIndexingResult(t *testing.T) {
	t.Parallel()

	// Use a different port to avoid conflicts
	port := 6881 + rand.IntN(1000)
	addr := fmt.Sprintf("127.0.0.1:%d", port)
	
	manager := NewManager([]string{addr}, 10, []string{addr}, nil)
	defer manager.Terminate()

	// Create a test result
	var infoHash [20]byte
	copy(infoHash[:], "test-infohash-12345")
	
	result := mainline.NewIndexingResult(infoHash, []net.TCPAddr{{IP: net.ParseIP("127.0.0.1"), Port: 6881}})

	// Test that onIndexingResult doesn't panic
	manager.onIndexingResult(result)
	
	// Test that the result is sent to the output channel
	select {
	case <-manager.Output():
		// Success
	case <-time.After(100 * time.Millisecond):
		t.Error("Result should be sent to output channel")
	}
}

func TestManagerOnIndexingResultChannelFull(t *testing.T) {
	t.Parallel()

	// Use a different port to avoid conflicts
	port := 6881 + rand.IntN(1000)
	addr := fmt.Sprintf("127.0.0.1:%d", port)
	
	manager := NewManager([]string{addr}, 10, []string{addr}, nil)
	defer manager.Terminate()

	// Fill up the output channel
	for i := 0; i < ChanSize; i++ {
		var infoHash [20]byte
		copy(infoHash[:], fmt.Sprintf("test-infohash-%d", i))
		
		result := mainline.NewIndexingResult(infoHash, []net.TCPAddr{{IP: net.ParseIP("127.0.0.1"), Port: 6881}})
		manager.onIndexingResult(result)
	}

	// Test that adding one more result expands the channel
	var infoHash [20]byte
	copy(infoHash[:], "test-infohash-overflow")
	
	result := mainline.NewIndexingResult(infoHash, []net.TCPAddr{{IP: net.ParseIP("127.0.0.1"), Port: 6881}})
	
	// This should not block and should expand the channel
	manager.onIndexingResult(result)
	
	// Verify the channel was expanded by checking we can receive all results
	received := 0
	timeout := time.After(5 * time.Millisecond) // Very short timeout
	for {
		select {
		case <-manager.Output():
			received++
		case <-timeout:
			break
		}
		if received >= ChanSize+1 {
			break
		}
	}
	
	if received < ChanSize+1 {
		t.Errorf("Expected to receive at least %d results, got %d", ChanSize+1, received)
	}
}
