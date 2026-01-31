# Boomi CI/CD CLI Test Suite

This directory contains the automated test harness for the Boomi CI/CD CLI scripts.
It allows you to validate the logic of the shell scripts and the correctness of the generated JSON templates without requiring a connection to the real Boomi AtomSphere API.

## Directory Structure

*   **`run_tests.sh`**: The main entry point. This script sets up the test environment, runs the test cases, and asserts the results.
*   **`mocks/curl`**: A mock implementation of `curl`. It intercepts API calls made by the CLI scripts, logs the request details (URL, headers, body) to `workspace/request_log.json`, and returns mock JSON responses.
*   **`workspace/`**: A temporary directory where scripts write their output files (`tmp.json`, `out.json`, etc.) during testing.

## How to Run Tests

From the root of the repository:

```bash
./cli/tests/run_tests.sh
```

If successful, you will see output indicating that all tests passed:

```text
---------------------------------------------------
ALL TESTS PASSED
```

## How It Works

1.  **Environment Mocking**: The `run_tests.sh` script exports dummy environment variables like `authToken`, `baseURL`, `h1`, and `h2`, which are required by `common.sh`.
2.  **Path Override**: It prepends `cli/tests/mocks` to the `$PATH` variable. This forces the scripts to use our mock `curl` instead of the system `curl`.
3.  **Request Capture**: When a script calls `callAPI` (in `common.sh`), it executes `curl`. Our mock script captures the arguments and writes them to `workspace/request_log.json`.
4.  **Response Mocking**: The mock `curl` inspects the requested URL and returns a pre-defined JSON response (e.g., a mock Environment ID or Atom ID) to `out.json`, so the calling script can proceed.
5.  **Assertions**: After the script finishes, `run_tests.sh` uses `jq` to inspect `workspace/request_log.json` and verify that the expected JSON payload and URL were sent.

## Adding New Tests

To add a new test case, edit `cli/tests/run_tests.sh`:

1.  **Define a new test block**:
    ```bash
    setup_test "My New Script Test"
    export MOCK_RESPONSE_BODY='{"result": [{"id": "mock-id"}]}'
    export myParam="value"
    ```

2.  **Run the script**:
    ```bash
    (cd "$SCRIPTS_HOME" && source "bin/myScript.sh" myParam="$myParam")
    ```

3.  **Add Assertions**:
    ```bash
    assert_url "ExpectedEndpoint" "Description of check"
    assert_request_body ".jsonKey" "expectedValue" "Description of check"
    ```
