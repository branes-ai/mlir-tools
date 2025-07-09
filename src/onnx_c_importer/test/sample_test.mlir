// RUN: onnx-c-importer %s | FileCheck %s

// Test basic ONNX import functionality
// This test verifies that the onnx-c-importer tool can process
// basic ONNX operations and convert them to Torch dialect

module {
  // Basic ONNX Add operation test
  func.func @test_onnx_add(%arg0: !torch.vtensor<[2,3],f32>, %arg1: !torch.vtensor<[2,3],f32>) -> !torch.vtensor<[2,3],f32> {
    // CHECK-LABEL: func.func @test_onnx_add
    // CHECK: torch.operator
    %0 = torch.operator "onnx.Add"(%arg0, %arg1) : (!torch.vtensor<[2,3],f32>, !torch.vtensor<[2,3],f32>) -> !torch.vtensor<[2,3],f32>
    return %0 : !torch.vtensor<[2,3],f32>
  }

  // Basic ONNX Constant operation test  
  func.func @test_onnx_constant() -> !torch.vtensor<[1],f32> {
    // CHECK-LABEL: func.func @test_onnx_constant
    // CHECK: torch.operator
    %0 = torch.operator "onnx.Constant"() {value = dense<1.000000e+00> : tensor<1xf32>} : () -> !torch.vtensor<[1],f32>
    return %0 : !torch.vtensor<[1],f32>
  }

  // Basic ONNX MatMul operation test
  func.func @test_onnx_matmul(%arg0: !torch.vtensor<[2,3],f32>, %arg1: !torch.vtensor<[3,4],f32>) -> !torch.vtensor<[2,4],f32> {
    // CHECK-LABEL: func.func @test_onnx_matmul
    // CHECK: torch.operator
    %0 = torch.operator "onnx.MatMul"(%arg0, %arg1) : (!torch.vtensor<[2,3],f32>, !torch.vtensor<[3,4],f32>) -> !torch.vtensor<[2,4],f32>
    return %0 : !torch.vtensor<[2,4],f32>
  }
}
