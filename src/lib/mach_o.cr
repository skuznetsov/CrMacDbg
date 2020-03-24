struct MachO
  property io : IO::Memory
  property magic : UInt32
  property cpuType : Debug::MachO::CpuType
  property cpuSubType : Int32
  property fileType : Debug::MachO::FileType
  property nCmds : UInt32
  property sizeOfCmds : UInt32
  property flags : Debug::MachO::Flags
  property baseAddress : UInt64 = 0_u64

  @ldoff : Int32
  @uuid : Debug::MachO::UUID?
  @symtab : Debug::MachO::Symtab?
  @stabs : Array(Debug::MachO::StabEntry)?
  @symbols : Array(Debug::MachO::Nlist64)?

  def initialize(buf : Array(UInt8))
    @io = IO::Memory.new(Slice.new(buf.to_unsafe, buf.size))
    @magic = read_magic
    @cpuType = Debug::MachO::CpuType.new(@io.read_bytes(Int32, endianness))
    @cpuSubType = @io.read_bytes(Int32, endianness)
    @fileType = Debug::MachO::FileType.new(@io.read_bytes(UInt32, endianness))
    @nCmds = @io.read_bytes(UInt32, endianness)
    @sizeOfCmds = @io.read_bytes(UInt32, endianness)
    @flags = Debug::MachO::Flags.new(@io.read_bytes(UInt32, endianness))
    @io.skip(4) if abi64? # reserved
    @ldoff = @io.tell
    @segments = [] of Debug::MachO::Segment64
    @sections = [] of Debug::MachO::Section64
  end

  def to_s(io : IO) : Nil
    io << "Magic: " << @magic
    io << "\nCPU Type: " << @cpuType
    io << "\nCPU SubType: " << @cpuSubType
    io << "\nFile Type: " << @fileType
    io << "\nComands No: " << @nCmds
    io << "\nSize of Commands: " << @sizeOfCmds
    io << "\nFlag: " << @flags
    io << "\nSegments:" << show_segments
    io << "\nSections:" << show_sections
    io
  end

  def read_magic
    magic = @io.read_bytes(UInt32)
    unless magic == Debug::MachO::MAGIC_64 || magic == Debug::MachO::CIGAM_64 || magic == Debug::MachO::MAGIC || magic == Debug::MachO::CIGAM
      raise Exception.new("Invalid magic number")
    end
    magic
  end

  def abi64?
    cpuType.value.bits_set? Debug::MachO::ABI64
  end

  def endianness
    if @magic == Debug::MachO::MAGIC_64 || @magic == Debug::MachO::MAGIC
      IO::ByteFormat::SystemEndian
    elsif IO::ByteFormat::SystemEndian == IO::ByteFormat::LittleEndian
      IO::ByteFormat::BigEndian
    else
      IO::ByteFormat::LittleEndian
    end
  end

  # Seek to the first matching load command, yields, then returns the value of
  # the block.
  private def seek_to(load_command : Debug::MachO::LoadCommand)
    seek_to_each(load_command) do |cmd, cmdsize|
      return yield cmdsize
    end
  end

  # Seek to each matching load command, yielding each of them.
  private def seek_to_each(load_command : Debug::MachO::LoadCommand) : Nil
    @io.seek(@ldoff)

    nCmds.times do
      cmd = Debug::MachO::LoadCommand.new(@io.read_bytes(UInt32, endianness))
      cmdsize = @io.read_bytes(UInt32, endianness)

      if cmd == load_command
        yield cmd, cmdsize
      else
        @io.skip(cmdsize - 8)
      end
    end
  end

  def segments
    read_segments_and_sections if @segments.empty?
    @segments
  end

  def sections
    read_segments_and_sections if @sections.empty?
    @sections
  end

  private def read_segments_and_sections
    seek_to_each(Debug::MachO::LoadCommand::SEGMENT_64) do |cmd, cmdsize|
      segment = Debug::MachO::Segment64.new
      segment.segname = read_name
      segment.vmaddr = @io.read_bytes(UInt64, endianness)
      segment.vmsize = @io.read_bytes(UInt64, endianness)
      segment.fileoff = @io.read_bytes(UInt64, endianness)
      segment.filesize = @io.read_bytes(UInt64, endianness)
      segment.maxprot = @io.read_bytes(UInt32, endianness)
      segment.initprot = @io.read_bytes(UInt32, endianness)
      segment.nsects = @io.read_bytes(UInt32, endianness)
      segment.flags = @io.read_bytes(UInt32, endianness)
      @segments << segment

      segment.nsects.times do
        section = Debug::MachO::Section64.new(segment)
        section.sectname = read_name
        section.segname = read_name
        section.addr = @io.read_bytes(UInt64, endianness)
        section.size = @io.read_bytes(UInt64, endianness)
        section.offset = @io.read_bytes(UInt32, endianness)
        section.align = @io.read_bytes(UInt32, endianness)
        section.reloff = @io.read_bytes(UInt32, endianness)
        section.nreloc = @io.read_bytes(UInt32, endianness)
        section.flags = @io.read_bytes(UInt32, endianness)
        @io.skip(12)
        @sections << section
      end
    end
  end

  def symtab
    @symtab ||= seek_to(Debug::MachO::LoadCommand::SYMTAB) do
      symtab = Debug::MachO::Symtab.new
      symtab.symoff = @io.read_bytes(UInt32, endianness)
      symtab.nsyms = @io.read_bytes(UInt32, endianness)
      symtab.stroff = @io.read_bytes(UInt32, endianness)
      symtab.strsize = @io.read_bytes(UInt32, endianness)
      symtab
    end.not_nil!
  end

  def uuid
    @uuid ||= seek_to(Debug::MachO::LoadCommand::UUID) do
      bytes = uninitialized UInt8[16]
      @io.read_fully(bytes.to_slice)
      Debug::MachO::UUID.new(bytes)
    end.not_nil!
  end

  def symbols
    @symbols ||= Array(Debug::MachO::Nlist64).new(symtab.nsyms) do
      nlist = Debug::MachO::Nlist64.new
      nlist.strx = @io.read_bytes(UInt32, endianness)
      nlist.type = Debug::MachO::Nlist64::Type.new(@io.read_byte.not_nil!)
      nlist.sect = @io.read_byte.not_nil!
      nlist.desc = @io.read_bytes(UInt16, endianness)
      nlist.value = @io.read_bytes(UInt64, endianness)

      if nlist.strx > 0
        @io.seek(symtab.stroff + nlist.strx) do
          nlist.name = @io.gets('\0', chomp: true).to_s
        end
      end

      nlist
    end
  end

  def stabs
    @stabs ||= symbols.compact_map do |nlist|
      if stab = nlist.stab?
        Debug::MachO::StabEntry.new(stab, nlist.name, nlist.sect, nlist.desc, nlist.value)
      end
    end
  end

  private def read_name
    bytes = uninitialized StaticArray(UInt8, 16)
    @io.read_fully(bytes.to_slice)
    len = bytes.size
    while len > 0 && bytes[len - 1] == 0
      len -= 1
    end
    String.new(bytes.to_unsafe, len)
  end

  def read_section?(name)
    if sh = sections.find { |s| s.sectname == name }
      orig_offset = @io.pos
      @io.seek(sh.offset)
      result = yield sh, @io
      @io.seek(orig_offset)
      result
    end
  end

  def show_segment(segment : Debug::MachO::Segment64) : String
    str = String::Builder.new
    str << "\nName: " << segment.segname
    str << ", VM Addr: " << segment.vmaddr.to_s(16)
    str << ", rel_addr: 0x" << (segment.vmaddr &- 0x100000000 &+ baseAddress).to_s(16)
    str << ", VM Size: " << segment.vmsize
    str << ", File Offset: " << segment.fileoff.to_s(16)
    str << ", File Size: " << segment.filesize
    str << ", Maximum Prot: " << segment.maxprot
    str << ", Initial Prot: " << segment.initprot
    str << ", nSects: " << segment.nsects
    str << ", flags: " << segment.flags

    str.to_s
  end

  def show_segments
    result = String::Builder.new(1024)
    @segments.each do |segment|
      result << show_segment(segment)
    end
    result.to_s
  end

  def show_section(section : Debug::MachO::Section64) : String
    str = String::Builder.new
    str << "\nsegment: " << section.segment.segname
    str << ", sectname: " << section.sectname
    str << ", segname: " << section.segname
    str << ", addr: 0x" << section.addr.to_s(16)
    str << ", rel_addr: 0x" << (section.addr &- 0x100000000 &+ baseAddress).to_s(16)
    str << ", size: " << section.size
    str << ", offset: " << section.offset
    str << ", align: " << section.align
    str << ", reloff: " << section.reloff
    str << ", nreloc: " << section.nreloc
    str << ", flags: " << Debug::MachO::Flags.new(section.flags)
    str.to_s
  end

  def show_sections
    result = String::Builder.new(1024)
    @sections.each do |section|
      result << show_section(section)
    end
    result.to_s
  end
end
