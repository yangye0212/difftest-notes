# LightSSS 基于内存的轻量级仿真快照

### 语雀

[语雀文档](https://xiangshan.yuque.com/euzvvh/cv6gyu/yvlupi)

### Verilator的savable机制

调研一下文中所说的 `Verilator`的 `savable`机制，及其文中所说为什么仿真工具提供的快照功能将无法保存这些模型的状态？

`save/restore`类不是多线程的，只能由 eval 线程调用

`save/restore`

可以保存 Verilated 模型的中间状态，以便以后可以恢复

要启用此功能，请使用 `--savable`。`--savable`支持哪些语言功能将存在一些限制；如果您尝试使用不受支持的功能 `Verilator` 将抛出错误。

要使用 `save/restore`，用户编写的代码必须创建一个 `VerilatedSerialize` 或 `VerilatedDeserialze` 对象，然后调用
`<<` 或 `>>` 操作符在生成模型上的以及过程需要 `save/restore`的任何其他数据。这些功能不是线程安全的，通常只由主线程调用。

文档例程

```cpp
void save_model(const char* filenamep) {
  VerilatedSave os;
  os.open(filenamep);
  os << main_time; // user code must save the timestamp, etc
  os << *topp;
}
void restore_model(const char* filenamep) {
  VerilatedRestore os;
  os.open(filenamep);
  os >> main_time;
  os >> *topp;
}
```

### difftest `savable`

由宏定义 `VM_SAVABLE`展开代码

### difftest LightSSS fork进程

LightSSS抽象的类定义

```cpp
class LightSSS {
  pid_t pid   = -1;
  int slotCnt = 0;
  int waitProcess = 0;
  std::list<pid_t> pidSlot = {};
  ForkShareMemory forkshm;

public:
  int do_fork();
  int wakeup_child(uint64_t cycles);
  bool is_child();
  int do_clear();
  uint64_t get_end_cycles() {
    return forkshm.info->endCycles;
  }
};
```

在 `Emulator`构造函数中可以看到，使用LightSSS的fork则会在开始出关闭波形打印

```cpp
// Emulator::Emulator(int argc, const char *argv[])
enable_waveform = args.enable_waveform && !args.enable_fork;
```

LightSSS方法 `LightSSS::do_fork()`，由源码知道，该方法内会调用fork()

> 在父进程中，fork返回新创建的子进程的PID;
> 在子进程中，fork返回0;
> 出现错误，fork返回一个负值

```cpp
int LightSSS::do_fork() {
  //kill the oldest blocked checkpoint process
  if (slotCnt == SLOT_SIZE) {
    pid_t temp = pidSlot.back();
    pidSlot.pop_back();
    kill(temp, SIGKILL);
    int status = 0;
    waitpid(temp, NULL, 0);
    slotCnt--;
  }
  // fork a new checkpoint process and block it
  if ((pid = fork()) < 0) {
    eprintf("[%d]Error: could not fork process!\n", getpid()) ;
    return FORK_ERROR;
  }
  // the original process
  else if (pid != 0) {
    slotCnt++;
    pidSlot.insert(pidSlot.begin(), pid);
    return FORK_OK;
  }
  // for the fork child
  waitProcess = 1;
  forkshm.shwait();
  //checkpoint process wakes up
  //start wave dumping
  bool is_last = forkshm.info->oldest == getpid();
  return (is_last) ? WAIT_LAST : WAIT_EXIT;
}
```

该处可知，在父进程和子进程中，此处的返回值不相同，可以得到很重要的信息，可根据该返回值知道是子进程还是父进程，并作不同的操作。

由 `fork()`创建进程后，父进程和子进程都从fork之后的代码开始执行，并且根据系统的进程调度策略来获取CPU资源来执行

可知子进程将会执行 `forkshm.shwait();`，进入一个休眠状态

```cpp
void ForkShareMemory::shwait() {
  while (true) {
    if (info->flag ) {
      if(info->notgood) break;
      else exit(0);
    }
    else {
      sleep(WAIT_INTERVAL);
    }
  }
}
```

这里可以想象，有相应的休眠函数，那应该有相应的唤醒函数去唤醒子线程打印波形

```cpp
int LightSSS::wakeup_child(uint64_t cycles) {
  forkshm.info->endCycles = cycles;
  forkshm.info->oldest = pidSlot.back();
  forkshm.info->notgood = true;
  forkshm.info->flag = true;
  int status = -1;
  waitpid(pidSlot.back(), &status, 0);
  return 0;
}
```

有

来看在仿真过程中的主循环里怎么调用上述函数去fork一个子进程

```cpp
  if (args.enable_fork) {
    static bool have_initial_fork = false;
    uint32_t timer = uptime();
    //check if it's time to fork a checkpoint process
    if (((timer - lasttime_snapshot > 1000 * FORK_INTERVAL) || !have_initial_fork) && !is_fork_child()) {
      have_initial_fork = true;
      lasttime_snapshot = timer;
      switch (lightsss.do_fork()) {
        case FORK_ERROR: return -1;
        case WAIT_EXIT: exit(0);
        case WAIT_LAST: fork_child_init();
        default: break;
      }
    }
  }
```

如果参数里打开了该 fork 功能，调用封装好的函数 `timer()`获取该emu开始运行到现在的时间，

若该进程不是子进程，并且该进程还未创建子进程或者距上次创建子进程的时间（变量 `lasttime_snapshot`）大于1秒(`1000 * FORK_INTERVAL`，该处宏 `FORK_INTERVAL`默认为1)，则创建一个子进程，并更新相应的变量

站在父进程角度看：

创建子进程后回到周期推进的循环中继续仿真执行，直到某一个退出条件结束仿真循环后，在后续的代码中去唤醒一个子进程，并将主进程结束时的周期数告诉子进程

```cpp
  if (args.enable_fork) {
    bool need_wakeup = trapCode != STATE_GOODTRAP && trapCode != STATE_LIMIT_EXCEEDED && trapCode != STATE_SIG;
    if (need_wakeup) {
      lightsss.wakeup_child(cycles);
    }
    printf("*************** ");
    printf("%s", is_fork_child() ? "CHECHPOINT" : "MAIN");
    printf(" INFO START (PID %d) ***************\n", getpid());
    //when reach maximum instruction, clear the checkpoint process
    if (!is_fork_child()) {
      lightsss.do_clear();
    }
  }
```

那么，这里就有新的问题了，怎么告诉子进程呢？需要做进程间的通信了

linux 消息队列相关函数

```cpp
// 函数原型
key_t ftok(const char *pathname, int proj_id);
// 得到一个共享内存标识符或创建一个共享内存对象并返回共享内存标识符
int shmget(key_t key, size_t size, int shmflg);
// 把共享内存区对象映射到调用进程的地址空间
void *shmat(int shmid, const void *shmaddr, int shmflg);
```

通过linux的相关函数创建了一个所有进程的共享内存空间，以此来进行通信，在 `LightSSS.h`和 `LightSSS.cpp`中可以看到相关实现和定义：
