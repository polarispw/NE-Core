# 双发射五级流水CPU-AXI func test

## 关于双发测试的一些必要改动

- `cache_bank, dcache_tag, icache_bank, icache_tag`文件夹中只要把`xci`文件加入项目就行
- testbench相关内容：

写回段debug时在高低电平分别检测两条指令执行情况（`WB.v`已经修改过，不需要再改动，上板时不用这样双边检测）

同时修改test_bench的检测时机，从上沿改成电平检测

```verilog
118	always @(cpu_clk)
147	always @(cpu_clk)
248	always @(cpu_clk)
```

## 接入cache后针对流水线的调整

- 处理cache的stall请求时中断整条流水线
- 中断时注意锁住访存的使能信号
- 缺页中断和例外同时发生时先处理中断
- 在上一条的情况下流水线还有写数据操作的话要屏蔽使能信号，先处理例外
