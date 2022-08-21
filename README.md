# 更新文档

## 功能测试

- `axi4`里包含了封装成axi接口的CPU，可以通过`soc_axi_func`测试

## 性能测试

- 复制`golden_trace`到`perf_test_v0.01`目录下

- 依照性能测试说明文档1.5.1方法一的步骤仿真指定程序

- 修改`soc_axi_perf`下`testbench`文件

```verilog
35  `define TRACE_REF_FILE "../../../../../../../golden_trace/golden_traceX.txt", 	X为仿真测例号
39  `define CONFREG_OPEN_TRACE 1'b1
```

- 修改test_bench的检测时机，从上沿改成电平检测

```verilog
120 always @(cpu_clk)
149 always @(cpu_clk)
250 always @(cpu_clk)
```

## 关键路径

| 路径描述                                                     | 修改方案 | 最高频率   |
| ------------------------------------------------------------ | -------- | ---------- |
| dcache未命中发出阻塞信号—>在cache阻塞时要屏蔽例外请求—>IF段的pc发生变化 |          | 70M（TLB） |
|                                                              |          |            |