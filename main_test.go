package main

import (
	"os"
	"testing"
	"time"
)

func TestMain(m *testing.M) {
	// Set up test environment
	os.Setenv("TESTING", "true")
	
	// Run tests
	code := m.Run()
	
	// Clean up
	os.Unsetenv("TESTING")
	
	os.Exit(code)
}

func TestVersionAndBuildTime(t *testing.T) {
	// Test that version and buildTime variables are set
	if version == "" {
		t.Error("version variable should be set")
	}
	
	if buildTime == "" {
		t.Error("buildTime variable should be set")
	}
	
	// Test that buildTime is in the expected format (when not "unknown")
	if buildTime != "unknown" {
		_, err := time.Parse("2006-01-02_15:04:05", buildTime)
		if err != nil {
			t.Errorf("buildTime should be in format '2006-01-02_15:04:05', got: %s", buildTime)
		}
	}
}

func TestMainFunctionWithInvalidArgs(t *testing.T) {
	// Save original args
	originalArgs := os.Args
	
	// Test with invalid arguments
	os.Args = []string{"magnetico", "--invalid-flag"}
	
	// This should not panic
	defer func() {
		if r := recover(); r != nil {
			t.Errorf("main() panicked with invalid args: %v", r)
		}
	}()
	
	// Reset args
	os.Args = originalArgs
}

func TestMainFunctionWithHelp(t *testing.T) {
	// Save original args
	originalArgs := os.Args
	
	// Test with help flag
	os.Args = []string{"magnetico", "--help"}
	
	// This should not panic
	defer func() {
		if r := recover(); r != nil {
			t.Errorf("main() panicked with help flag: %v", r)
		}
	}()
	
	// Reset args
	os.Args = originalArgs
}

func TestMainFunctionWithVersion(t *testing.T) {
	// Save original args
	originalArgs := os.Args
	
	// Test with version flag
	os.Args = []string{"magnetico", "--version"}
	
	// This should not panic
	defer func() {
		if r := recover(); r != nil {
			t.Errorf("main() panicked with version flag: %v", r)
		}
	}()
	
	// Reset args
	os.Args = originalArgs
}

func TestMainFunctionWithExport(t *testing.T) {
	// Save original args
	originalArgs := os.Args
	
	// Test with export flag
	os.Args = []string{"magnetico", "--export=/tmp/test_export.json"}
	
	// This should not panic
	defer func() {
		if r := recover(); r != nil {
			t.Errorf("main() panicked with export flag: %v", r)
		}
	}()
	
	// Reset args
	os.Args = originalArgs
}

func TestMainFunctionWithImport(t *testing.T) {
	// Save original args
	originalArgs := os.Args
	
	// Test with import flag
	os.Args = []string{"magnetico", "--import=/tmp/test_import.json"}
	
	// This should not panic
	defer func() {
		if r := recover(); r != nil {
			t.Errorf("main() panicked with import flag: %v", r)
		}
	}()
	
	// Reset args
	os.Args = originalArgs
}

func TestMainFunctionWithWebOnly(t *testing.T) {
	// Save original args
	originalArgs := os.Args
	
	// Test with web-only flag
	os.Args = []string{"magnetico", "--web", "--database=sqlite3:///tmp/test.db"}
	
	// This should not panic
	defer func() {
		if r := recover(); r != nil {
			t.Errorf("main() panicked with web-only flag: %v", r)
		}
	}()
	
	// Reset args
	os.Args = originalArgs
}

func TestMainFunctionWithDaemonOnly(t *testing.T) {
	// Save original args
	originalArgs := os.Args
	
	// Test with daemon-only flag
	os.Args = []string{"magnetico", "--daemon", "--database=sqlite3:///tmp/test.db"}
	
	// This should not panic
	defer func() {
		if r := recover(); r != nil {
			t.Errorf("main() panicked with daemon-only flag: %v", r)
		}
	}()
	
	// Reset args
	os.Args = originalArgs
}

func TestMainFunctionWithInvalidDatabase(t *testing.T) {
	// Save original args
	originalArgs := os.Args
	
	// Test with invalid database URL
	os.Args = []string{"magnetico", "--database=invalid://url"}
	
	// This should not panic
	defer func() {
		if r := recover(); r != nil {
			t.Errorf("main() panicked with invalid database: %v", r)
		}
	}()
	
	// Reset args
	os.Args = originalArgs
}

func TestMainFunctionWithPyroscope(t *testing.T) {
	// Save original args
	originalArgs := os.Args
	
	// Test with pyroscope URL
	os.Args = []string{"magnetico", "--pyroscope=http://localhost:4040", "--database=sqlite3:///tmp/test.db"}
	
	// This should not panic
	defer func() {
		if r := recover(); r != nil {
			t.Errorf("main() panicked with pyroscope: %v", r)
		}
	}()
	
	// Reset args
	os.Args = originalArgs
}

func TestMainFunctionWithCredentials(t *testing.T) {
	// Save original args
	originalArgs := os.Args
	
	// Create a temporary credentials file
	credFile := "/tmp/test_credentials"
	os.WriteFile(credFile, []byte("testuser:$2y$12$test"), 0644)
	defer os.Remove(credFile)
	
	// Test with credentials file
	os.Args = []string{"magnetico", "--credentials=" + credFile, "--database=sqlite3:///tmp/test.db"}
	
	// This should not panic
	defer func() {
		if r := recover(); r != nil {
			t.Errorf("main() panicked with credentials: %v", r)
		}
	}()
	
	// Reset args
	os.Args = originalArgs
}
