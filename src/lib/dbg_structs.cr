require "./dbg_structs"

lib CrDBGExt
  alias Policy = Int32

  enum VmRegionFlavour
    VM_REGION_BASIC_INFO_64 = 9
    VM_REGION_BASIC_INFO
    VM_REGION_EXTENDED_INFO
    VM_REGION_TOP_INFO
  end

  struct ExcMsg
    exceptionPort : UInt32
    thread : UInt32
    task : UInt32
    exception : Int32
    code : Int64
    codeCnt : UInt32
  end

  struct X86ThreadState64
    rax : UInt64
    rbx : UInt64
    rcx : UInt64
    rdx : UInt64
    rdi : UInt64
    rsi : UInt64
    rbp : UInt64
    rsp : UInt64
    r8 : UInt64
    r9 : UInt64
    r10 : UInt64
    r11 : UInt64
    r12 : UInt64
    r13 : UInt64
    r14 : UInt64
    r15 : UInt64
    rip : UInt64
    rflags : UInt64
    cs : UInt64
    fs : UInt64
    gs : UInt64
  end

  struct TaskInterface
    task : UInt32
    pid : UInt32

    breaks : BreakpointStruct**
    currentBreak : UInt32
    maxBreak : UInt32

    singleStepIndex : UInt32 # HACK FOR NOW FIX ME LATER
    singleStep : BreakpointStruct*

    exceptList : ExceptionHandler**
    currentException : UInt32
    maxException : UInt32

    registeredExceptionHandler : Int32
    kq : Int32
    serverPort : UInt32
  end

  struct BreakpointStruct
    original : UInt64
    address : UInt64
    handler : ExcMsg* -> Int32
    flags : Int32
    index : UInt64
    hit : UInt32
  end

  struct ExceptionHandler
    exception : Int32
    handler : ExcMsg* -> Int32
  end

  struct VmRegionBasicInfo64
    protection : Int32
    maxProtection : Int32
    inheritance : UInt32
    shared : UInt32
    reserved : UInt32
    offset : UInt64
    behavior : Int32
    userWiredCount : UInt16
  end

  # Ctype structure for vm_region_t
  struct VmRegion
    regionType : UInt32
    addressStart : UInt64
    addressEnd : UInt64
    size : UInt64
    protection : UInt32
    maxProtection : UInt32
    shareMode : UInt32
    regionDetail : UInt8*
  end

  # Ctype structure for dyld_info_struct
  struct DyldInfo
    startAddress : UInt64
    endAddress : UInt64
    regionType : UInt32
    size : UInt64
    path : UInt8*
    protection : UInt32
  end

  struct TimeValue
    seconds : Int32
    microseconds : Int32
  end

  # Ctype structure for thread_basic_info_t
  struct ThreadBasicInfo
    userTime : TimeValue
    systemTime : TimeValue
    cpuUsage : Int32
    policy : Policy
    runState : Int32
    flags : Int32
    suspendCount : Int32
    sleepTime : Int32
  end

  # Ctype structure for thread_identifier_info_data_t
  struct ThreadIdentInfo
    threadId : UInt64
    threadHandle : UInt64
    dispatchQaddr : UInt64
  end

  struct ProcThreadInfo
    userTime : UInt64
    systemTime : UInt64
    cpuUsage : Int32
    policy : Int32
    runState : Int32
    flags : Int32
    sleepTime : Int32
    curpri : Int32
    priority : Int32
    maxpriority : Int32
    name : UInt8
  end

  # MAX_EXCEPTION_PORTS = 32
  # struct MachExceptionHandlerData
  #     masks : UInt32[MAX_EXCEPTION_PORTS]
  #     exception_handler_t ports[MAX_EXCEPTION_PORTS];
  #     exception_behavior_t behaviors[MAX_EXCEPTION_PORTS];
  #     thread_state_flavor_t flavors[MAX_EXCEPTION_PORTS];
  #     mach_msg_type_number_t count;
  # end
end
