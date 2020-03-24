require "./dbg_structs"

@[Link(framework: "System")]
lib CrDBGExt
  $mach_task_self_ : UInt32

  fun task_for_pid(current_task : UInt32, pid : UInt32, task : UInt32*) : UInt32
  fun task_suspend(task : UInt32) : UInt32
  fun task_resume(task : UInt32) : UInt32
  fun mach_vm_read(task : UInt32, addr : UInt64, size : UInt64, buf : UInt8*, bufSize : UInt32*) : UInt32
  fun mach_vm_read_overwrite(task : UInt32, addr : UInt64, size : UInt64, buf : UInt8*, bufSize : UInt32*) : UInt32
  fun mach_vm_write(task : UInt32, addr : UInt64, buf : UInt8*, size : UInt32) : UInt32
  fun mach_error(msg : UInt8*, errCode : Int32) : Void
  fun mach_vm_region(task : UInt32, addr : UInt64*, size : UInt64*, flavour : UInt32, infoAddress : VmRegionBasicInfo64*, infoCount : UInt32*, objentName : UInt32*) : UInt32
  fun mach_vm_protect(task : UInt32, addr : UInt64, size : UInt64, setMaxinum : UInt8, newProtection : Int32) : UInt32
end

class CrDBG
  VM_PROT_NONE    =    0
  VM_PROT_READ    =  0x1
  VM_PROT_WRITE   =  0x2
  VM_PROT_EXECUTE =  0x4
  VM_PROT_COPY    = 0x10
  VM_PROT_DEFAULT = VM_PROT_READ | VM_PROT_WRITE
  VM_PROT_ALL     = VM_PROT_READ | VM_PROT_WRITE | VM_PROT_EXECUTE
end

class CrDBG
  @@Interfaces = [] of CrDBGExt::TaskInterface

  def self.current_task
    puts "[current_task]: Task # #{CrDBGExt.mach_task_self_}"
    CrDBGExt.mach_task_self_
  end

  def self.taskForPid(pid)
    rc = CrDBGExt.task_for_pid(self.current_task, pid, out task)
    puts "[taskForPid] Task # #{task}"
    if rc != 0
      CrDBGExt.mach_error("[taskForPid] ERROR (#{rc}): ", rc)
      exit 1
    end
    task
  end

  def self.suspendTask(task)
    puts "[suspendTask] Task # #{task}"
    rc = CrDBGExt.task_suspend(task)
    if rc != 0
      CrDBGExt.mach_error("[suspendTask] ERROR (#{rc}): ", rc)
      exit 1
    end
  end

  def self.resumeTask(task)
    puts "[resumeTask] Task # #{task}"
    rc = CrDBGExt.task_resume(task)
    if rc != 0
      CrDBGExt.mach_error("[resumeTask] ERROR (#{rc}): ", rc)
      exit 1
    end
  end

  def self.attach(pid)
    task = self.taskForPid(pid)
    iface = CrDBGExt::TaskInterface.new
    iface.task = task
    iface.pid = pid
    @@Interfaces << iface
    task
  end

  def self.findInterface(task)
    @@Interfaces.find do |iface|
      iface.task == task
    end
  end

  def self.readMemory(task, address, size)
    buf = Array(UInt8).new(size, 0)
    bufPtr = buf.to_unsafe
    rc = CrDBGExt.mach_vm_read_overwrite(task, address, size, bufPtr, out bufSize)
    if rc != 0
      CrDBGExt.mach_error("[readMemory] ERROR (#{rc}): ", rc)
      exit 1
    end
    if size != bufSize
      raise Exception.new("[readMemory] ERROR: Size does not match.")
    end
    # pp buf.size
    # puts "[readMemory] RC=#{rc}, in: #{size}, out: #{bufSize}, buf = #{buf}"
    buf
  end

  def self.writeMemory(task, address, buf : Array(UInt8))
    size = buf.size
    bufPtr = buf.to_unsafe
    puts "buf=#{buf}, size=#{size}, bufPtr=#{bufPtr}"
    rc = CrDBGExt.mach_vm_write(task, address, bufPtr, size)
    if rc != 0
      CrDBGExt.mach_error("[writeMemory] ERROR (#{rc}): ", rc)
      exit 1
    end
    # puts "[writeMemory] RC=#{rc}, size: #{size}, buf = #{buf}"
    buf
  end

  def self.getVmRegion(task, address)
    info = CrDBGExt::VmRegionBasicInfo64.new
    count = sizeof(typeof(info)).to_u32
    rc = CrDBGExt.mach_vm_region(task, pointerof(address), out size, CrDBGExt::VmRegionFlavour::VM_REGION_BASIC_INFO_64, pointerof(info), pointerof(count), out objectName)
    if rc != 0
      CrDBGExt.mach_error("[getBaseAddress] ERROR (#{rc}): ", rc)
      exit 1
    end
    info
  end

  def self.getBaseAddress(task)
    address : UInt64 = 1
    info = CrDBGExt::VmRegionBasicInfo64.new
    count = sizeof(typeof(info)).to_u32
    rc = CrDBGExt.mach_vm_region(task, pointerof(address), out size, CrDBGExt::VmRegionFlavour::VM_REGION_BASIC_INFO_64, pointerof(info), pointerof(count), out objectName)
    if rc != 0
      CrDBGExt.mach_error("[getBaseAddress] ERROR (#{rc}): ", rc)
      exit 1
    end
    address
  end

  def self.vmProtect(task, address, length, protection : Int32)
    # puts "CrDBGExt.mach_vm_protect(task=#{task}, address=#{address.to_s(16)}, length=#{length}, 0, protection=#{protection})"
    rc = CrDBGExt.mach_vm_protect(task, address, length, 0, protection)
    if rc != 0
      CrDBGExt.mach_error("[vmProtect] ERROR (#{rc}): ", rc)
      exit 1
    end
    address
  end

  def getMemoryMap(task)
  end
end
