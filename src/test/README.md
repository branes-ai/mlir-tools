\# Global test design for mlir-tools



\## Key Features of the Global Test Configuration



\### 1. \*\*Dependency Management\*\*

\- Checks for required testing tools (llvm-lit, FileCheck)

\- Sets up proper dependencies between tools and tests

\- Ensures all tools are built before running tests



\### 2. \*\*Configuration Setup\*\*

\- Configures the main lit site configuration file

\- Sets up proper paths for test execution

\- Exports variables for use by individual tool tests



\### 3. \*\*Test Targets\*\*

\- Creates a `check-mlir-tools-global` target for global tests

\- Integrates with the main `check-mlir-tools` target

\- Supports integration tests if they exist



\### 4. \*\*Extensible Design\*\*

\- Automatically detects available tools and adds them as dependencies

\- Supports adding integration tests in a separate subdirectory

\- Provides a foundation for cross-tool testing



\### 5. \*\*Proper Error Handling\*\*

\- Gracefully handles missing test tools with warnings

\- Provides detailed status messages for debugging



\## How It Works



1\. \*\*Tool Detection\*\*: Automatically finds built tools (like `onnx-c-importer`) and adds them as test dependencies

2\. \*\*Path Configuration\*\*: Sets up all the necessary paths for lit to find tools and test files

3\. \*\*Target Creation\*\*: Creates test targets that integrate with the overall build system

4\. \*\*Integration Support\*\*: Supports both individual tool tests and cross-tool integration tests



\## Usage



With this configuration, you can now run:



```bash

\# Run all tests

cmake --build . --target check-mlir-tools



\# Run just global tests

cmake --build . --target check-mlir-tools-global



\# Run specific tool tests

cmake --build . --target check-onnx-c-importer

```



This provides a robust testing infrastructure that scales as you add more tools to your project!

