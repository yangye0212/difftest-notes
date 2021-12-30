# LightSSS 基于内存的轻量级仿真快照


### 语雀
[语雀文档](https://xiangshan.yuque.com/euzvvh/cv6gyu/yvlupi)


### Verilator的savable机制
调研一下文中所说的`Verilator`的`savable`机制，及其文中所说为什么仿真工具提供的快照功能将无法保存这些模型的状态？

`save/restore`类不是多线程的，只能由 eval 线程调用

`save/restore`

可以保存 Verilated 模型的中间状态，以便以后可以恢复

要启用此功能，请使用 `--savable`。`--savable`支持哪些语言功能将存在一些限制；如果您尝试使用不受支持的功能 `Verilator` 将抛出错误。

要使用`save/restore`，用户编写的代码必须创建一个`VerilatedSerialize` 或 `VerilatedDeserialze` 对象，然后调用
`<<` 或 `>>` 操作符在生成模型上的以及过程需要`save/restore`的任何其他数据。这些功能不是线程安全的，通常只由主线程调用。

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

由宏定义`VM_SAVABLE`展开代码



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


LightSSS方法`LightSSS::do_fork()`，由源码知道，该方法内会调用fork()

> 在父进程中，fork返回新创建的子进程的PID;  
  在子进程中，fork返回0;  
  出现错误，fork返回一个负值



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

该处可知，在父进程和子进程中，此处的返回值不相同，可以得到很重要的信息，可根据该返回值知道是子进程还是父进程，并作不同的操作