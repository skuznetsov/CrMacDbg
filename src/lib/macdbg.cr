# @[Link("mcdb")]
# lib MacDBG
#     alias Policy = Int32

#     struct ExcMsg
#         exceptionPort: UInt32
#         thread: UInt32
#         task: UInt32
#         exception: Int32
#         code: Int64
#         codeCnt: UInt32
#     end

#     struct X86ThreadState64
#         rax: UInt64
#         rbx: UInt64
#         rcx: UInt64
#         rdx: UInt64
#         rdi: UInt64
#         rsi: UInt64
#         rbp: UInt64
#         rsp: UInt64
#         r8: UInt64
#         r9: UInt64
#         r10: UInt64
#         r11: UInt64
#         r12: UInt64
#         r13: UInt64
#         r14: UInt64
#         r15: UInt64
#         rip: UInt64
#         rflags: UInt64
#         cs: UInt64
#         fs: UInt64
#         gs: UInt64
#     end

#     # Ctype structure for breakpoint_struct
#     struct BreakpointStruct
#         original: UInt64
#         address: UInt64
#         handler: ExcMsg* -> Int32
#         flags: Int32
#         index: UInt64
#         hit: UInt32
#     end

#     # Ctype structure for exception_handler
#     struct ExceptionHandler
#         exception: Int32
#         handler: ExcMsg* -> Int32
#     end

#     # Ctype structure for vm_region_basic_info_data_64_t
#     struct VmRegionBasicInfo64
#         protection: Int32
#         max_protection: Int32
#         inheritance: UInt32
#         shared: UInt32
#         reserved: UInt32
#         offset: UInt64
#         behavior: Int32
#         user_wired_count: UInt16
#     end

#     # Ctype structure for vm_region_t
#     struct VmRegion
#         region_type: UInt32
#         address_start: UInt64
#         address_end: UInt64
#         size: UInt64
#         protection: UInt32
#         max_protection: UInt32
#         share_mode: UInt32
#         region_detail: UInt8*
#     end

#     #Ctype structure for dyld_info_struct
#     struct DyldInfo
#         start_addr: UInt64
#         end_addr: UInt64
#         region_type: UInt32
#         size: UInt64
#         path: UInt8*
#         protection: UInt32
#     end

#     struct TimeValue
#         seconds: Int32
#         microseconds: Int32
#     end

#     #Ctype structure for thread_basic_info_t
#     struct ThreadBasicInfo
#         user_time: TimeValue
#         system_time: TimeValue
#         cpu_usage: Int32
#         policy: Policy
#         run_state: Int32
#         flags: Int32
#         suspend_count: Int32
#         sleep_time: Int32
#     end

#     #Ctype structure for thread_identifier_info_data_t
#     struct ThreadIdentInfo
#         thread_id: UInt64
#         thread_handle: UInt64
#         dispatch_qaddr: UInt64
#     end

#     struct ProcThreadInfo
#         pth_user_time: UInt64
#         pth_system_time: UInt64
#         pth_cpu_usage: Int32
#         pth_policy: Int32
#         pth_run_state: Int32
#         pth_flags: Int32
#         pth_sleep_time: Int32
#         pth_curpri: Int32
#         pth_priority: Int32
#         pth_maxpriority: Int32
#         pth_name: UInt8
#     end

#     fun add_breakpoint(task : UInt32, patchAddr : UInt64, cont : Int32, handler : ExcMsg* -> Int32) : Int32
#     fun add_exception_callback(task : UInt32, handler : ExcMsg* -> Int32, exception : Int32) : Int32
#     fun allocate(task : UInt32, patchAddr : UInt64, size : LibC::SizeT, flags: Int32) : UInt64
#     fun attach(infoPid : UInt32) : Int32
#     fun allocate_space(task : UInt32, size : LibC::SizeT, flags: Int32) : UInt64
#     fun change_page_protection(task : UInt32, patchAddr : UInt64, new_protection: Int32) : Int32
#     fun continue = continue_(task : UInt32) : UInt32
#     fun detach(task : UInt32) : UInt32
#     fun exception_to_string( exception_code: Int32) : UInt8*
#     fun free_memory(task : UInt32, patchAddr : UInt64, size : LibC::SizeT) : Int32
#     fun find_pid(task : UInt32) : Int32
#     fun generic_callback(ExcMsg*) : Int32
#     fun get_task(pid : UInt32) : UInt32
#     fun get_dyld_map(task : UInt32, no_of_dyld : UInt32*) : DyldInfo**
#     fun get_base_address(task : UInt32) : UInt64
#     fun get_image_size(task : UInt32, address: UInt64) : UInt64
#     fun get_memory_map(task : UInt32, address: UInt64, region: Int32*) : VmRegion**
#     fun get_protection(protection: Int32) : UInt8*
#     fun get_region_info(task : UInt32, address: UInt64) : VmRegionBasicInfo64*
#     fun get_state(thread : UInt32) : X86ThreadState64*
#     fun get_proc_threadinfo(pid : UInt32, thread_handle: UInt64) : ProcThreadInfo*
#     fun kqueue_loop(kp: Int32) : Void*
#     fun list_breaks(task : UInt32, count: UInt32*) : UInt32*
#     fun print_byte(byte : UInt8*) : Void
#     fun read_memory(task : UInt32, address: UInt64, size: LibC::SizeT) : UInt8*
#     fun read_memory_allocate(task : UInt32, address: UInt64, size: LibC::SizeT) : UInt8*
#     fun remove_all_breaks(task : UInt32) : Void
#     fun remove_breakpoint(task : UInt32, bp : BreakpointStruct*) : Int32
#     fun remove_exception_callback( handler: ExceptionHandler* ) : ExceptionHandler*
#     fun run( command: UInt8*, args: UInt8**) : UInt32
#     fun safe_malloc( size: LibC::SizeT) : Void*
#     fun set_thread_state(thread : UInt32, break_state: X86ThreadState64* ) : Int32
#     fun spawn_process(command: UInt8*, args: UInt8**) : Int32
#     fun start(task : UInt32, infoPid: UInt32) : Void
#     fun suspend(task : UInt32) : Void
#     fun terminate = terminate_(task : UInt32) : Int32
#     fun test() : Void
#     fun thread_count(task : UInt32) : UInt32
#     # fun thread_list_info(task : UInt32, POINTER(POINTER(c_void_p)), POINTER(c_int)) : Int32
#     # fun get_thread_basic_info(task : UInt32"                                      , "POINTER(ThreadBasicInfo)"),
#     # fun get_thread_identifier_info(task : UInt32"                                      , "POINTER(ThreadIdentInfo)"),
#     # fun thread_state(task : UInt32, c_uint"                              , "POINTER(X86ThreadState64)"),
#     # fun write_memory(task : UInt32, c_ulong, c_ulong, c_ulonglong"       , "None"),
#     # fun get_page_protection(task : UInt32, c_ulonglong"                         , "c_char_p"),
#     # fun inject_code(task : UInt32, c_char_p, c_uint"                    , "c_ulonglong"),
#     # fun write_bytes(task : UInt32, c_ulonglong, c_char_p, c_uint"       , "c_ulonglong"),
#     # fun thread_resume_(task : UInt32"                                      , "c_uint"),
#     # fun thread_suspend_(task : UInt32"                                      , "c_uint"),
#     # fun thread_terminate_(task : UInt32"                                      , "c_uint")

# end
