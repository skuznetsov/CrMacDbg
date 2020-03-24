# require "./lib/macdbg"
require "./lib/crdbg"
require "./lib/mach_o"
require "./lib/dwarf"

module Crmacdbg
  VERSION = "0.1.0"

  command = ARGV[0]
  pp command

  # input = IO::Memory.new
  output = IO::Memory.new
  process = Process.new command, output: output
  pid = process.pid
  puts "PID: #{pid}"
  # sleep(2.seconds)

  task = CrDBG.attach(pid)
  if task == 0
    puts "Task id is 0"
    exit 1
  end
  puts "Task: #{task}"

  CrDBG.suspendTask(task)

  baseAddress = CrDBG.getBaseAddress(task)
  puts "baseAddress: #{baseAddress.to_s(16)}"

  # dwarf = DWARF::Reader.open(__DIR__ + "/../test/crystal.dwarf")
  # dwarf.base_address = 0x100000000
  # dwarf.read # baseAddress

  buf = CrDBG.readMemory(task, baseAddress, 0x1000)
  macho = MachO.new(buf)
  macho.baseAddress = baseAddress
  macho.segments
  puts "Mach-O: #{macho}"
  puts "Mach-O symtab: #{macho.symtab}"

  region = CrDBG.getVmRegion(task, baseAddress + 0x1040)
  puts "Region: #{region}"

  needsChangeProtection = false
  if !(region.protection & CrDBG::VM_PROT_WRITE)
    puts "Changing protection"
    CrDBG.vmProtect(task, baseAddress + 0x1040, 1, CrDBG::VM_PROT_READ | CrDBG::VM_PROT_WRITE)
    region = CrDBG.getVmRegion(task, baseAddress + 0x1040)
    puts "Region: #{region}"
    needsChangeProtection = true
  end
  buf = CrDBG.readMemory(task, baseAddress + 0x1040, 3)

  puts "buf before: #{buf}"
  CrDBG.writeMemory(task, baseAddress + 0x1040, ['b'.ord.to_u8])
  if needsChangeProtection
    puts "Restoring protection"
    CrDBG.vmProtect(task, baseAddress + 0x1040, 1, region.protection)
  end
  buf = CrDBG.readMemory(task, baseAddress + 0x1040, 3)
  puts "buf after: #{buf}"
  CrDBG.resumeTask(task)
end
