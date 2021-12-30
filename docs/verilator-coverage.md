# Verilator Coverage 覆盖率分析

[Verilator手册](https://verilator.org/guide/latest/simulating.html#coverage-analysis)

## 覆盖率分析 Coverage Analysis

verilator可以在Verilated模型中添加代码来支持verilog代码的覆盖率。需要在verilator的命令里添加参数`--coverage`。

verilator支持所有的覆盖率分析：

+ 功能覆盖（Functional Coverage)
+ 行覆盖率（Line Coverage）
+ 跳转覆盖率（Toggle Coverage）

当附带coverage的verilated的模型执行时，将创建一个coverage文件用于收集和之后的分析。

## 功能覆盖（Functional Coverage)

携带参数`--coverage`或`--coverage-user`，Verilator将用户在SystemVerilog设计中手动插入的功能覆盖点转换为Verilated模型。

目前，所有功能覆盖点都是使用SystemVerilog assertion语法指定的，必须使用`--assert`参数单独启用该语法。

例如，以下SystemVerilog语句将在覆盖名称“DefaultClock”下添加一个覆盖点：

`DefaultClock: cover property (@(posedge clk) cyc==3);`

## 行覆盖率（Line Coverage）

> 记录程序的各行代码被执行的情况。

使用`--coverage`或`--coverage-line`参数，Verilator 将在每个代码流变化点（例如在分支处）自动添加覆盖分析。在每个这样的分支处有唯一的计数器递增。在测试结束时，所有的计数器连同与每个计数器对应的文件名和行号将被写入覆盖文件。

Verilator 会自动禁用包含 $stop 的分支的覆盖，因为假定 $stop 分支包含不应发生的错误检查。一个`/*verilator coverage_block_off*/` 元注释将在该块中或之下的任何代码执行类似的功能，或 `/*verilator coverage_off*/`与 `/*verilator coverage_on*/`将分别禁用和打开代码块附近的覆盖使能。

当组合（非时钟）块接收到禁用 UNOPTFLAT 警告的信号时，Verilator 可能会超量计数；为了获得最准确的结果，在使用覆盖率时不要禁用此警告。

## 翻转覆盖率（Toggle Coverage）

> 记录单bit信号变量的值为0/1跳转情况，如从0到1，或者从1到0的跳转。


使用`--coverage`或`--coverage-toggle`参数，Verilator 将自动将跳转覆盖率分析添加到 Verilated 模型中。

模块中每个信号的每一位都插入了一个计数器。计数器将在相应位的每个边沿变化时递增。

作为任务或开始/结束块的一部分的信号被视为局部变量，不包括在内。以下划线开头的信号（见`--coverage-underscore`），是整数或非常宽（所有维度的总存储超过 256 位，见`--coverage-max-width`）也不包括在内。

层次结构被压缩，这样如果一个模块被多次实例化，则覆盖率将在该模块的所有实例化中与具有相同参数集的那个位相加。使用不同参数值实例化的模块被视为不同的模块，并将单独计算。

Verilator 对信号进入哪个时钟域做出最低限度的智能决定，并且只在该时钟域中寻找边沿。这意味着如果知道接收逻辑而导致无法看到边沿变化，则可以忽略边缘。该算法将来可能会改进。最终结果是覆盖率可能低于通过查看迹线看到的覆盖率，但覆盖率更准确地表示了设计中的激励质量。

当模型稳定时，可能会在时间零附近计数边沿。在释放重置之前将所有覆盖归零是一个很好的做法，以防止计算此类行为。

元注释对`/*verilator coverage_off*/`、 `/*verilator coverage_on*/`可用于不需要跳转覆盖分析的信号，例如 RAM 和寄存器文件。

## 覆盖率收集（Coverage Collection）
当任何覆盖标志用于 Verilate 时，Verilator 将在模型中添加适当的覆盖点插入并收集覆盖数据。

要从模型中获取覆盖数据，在用户编写的代码中，通常在测试通过后的最后，调用`Verilated::threadContextp()->coveragep()->write`通过覆盖率数据文件的文件名做参数，以将覆盖数据写入该文件（通常为`“logs/coverage.dat”` ）。

在不同的目录中运行每个测试，可能是并行的。每个测试都会创建一个`logs/coverage.dat`文件。

运行所有测试后，执行 `verilator_coverage` 命令，传递指向所有单个覆盖文件的文件名的参数。 `verilator_coverage`将读取 `logs/coverage.dat`文件，并生成带注释的源代码，显示代码覆盖率详细信息（`%`开头的信息）。(例如命令`verilator_coverage --annotate logs/annotated logs/coverage.dat`)

`verilator_coverage`也可用于测试分数，计算哪些测试对于完全覆盖设计很重要。

例如，请参见`examples/make_tracing_c/logs`目录。grep命令以 '%' 开头的行以输出 Verilator 认为哪些行需要更多覆盖（如`grep "^%" xxx.v` ）。

`verilator_coverage` 的其他参数选项允许合并覆盖数据文件或其他转换。

信息文件可以由 `verilator_coverage` 写入以导入 `lcov`。这允许将`genhtml`用于 HTML 报告并将报告导入到诸如`https://codecov.io` 之类的站点。

## 代码分析

Verilated 模型可以使用 GCC 或 Clang 的 C++ 分析机制进行代码分析。Verilator 提供了额外的标志来帮助将生成的 C++ 分析结果映射回负责分析的 C++ 代码函数的原始 Verilog 代码。

要使用分析：

1. 使用 Verilator 的`--prof-cfuncs`。
2. 构建并运行仿真模型。
3. 该模型将创建 gmon.out。
4. 运行`gprof`以查看时间花费在 C++ 代码中的哪个位置。
5. 通过verilator_profcfunc程序运行 gprof 输出，它会告诉您大部分时间花费在哪些 Verilog 行号上。

## 实验

在该project的Makefile中已经添加和src源码已经添加支持

执行以下命令生成`logs/coverage.dat`文件。
```bash
make clean
Make EMU_COVERAGE=1
```

执行以下命令生成带注释的源代码（在`logs/annotated`目录下）。
```bash
verilator_coverage --annotate logs/annotated logs/coverage.dat
```
看到以下输出表示成功
```bash
Total coverage (8/17) 47.00%
See lines with '%00' in logs/annotated
```

可以看到在指定目录下生成了相同的源码文件，打开文件可以看到一些以`%`开头注释的信息，或者以grep命令输出以 % 开头的行`grep "^%" SimTop.v` 



