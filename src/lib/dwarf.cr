require "./dwarf/*"
require "benchmark"

module DWARF
  def self.read_unsigned_leb128(io : IO)
    result = 0_u32
    shift = 0

    loop do
      byte = io.read_byte.not_nil!.to_i
      result |= (byte & 0x7f) << shift
      break if byte.bit(7) == 0
      shift += 7
    end

    result
  end

  def self.read_signed_leb128(io : IO)
    result = 0_i32
    shift = 0
    size = 32
    byte = 0_u8

    loop do
      byte = io.read_byte.not_nil!.to_i
      result |= (byte & 0x7f) << shift
      shift += 7
      break if byte.bit(7) == 0
    end

    # sign bit of byte is 2nd high order bit (0x40)
    if (shift < size) && (byte.bit(6) == 1)
      # sign extend
      result |= -(1 << shift)
    end

    result
  end

  class Reader
    struct ProcEntry
      property low_pc : UInt64
      property high_pc : UInt64
      property func_name : String
      property line_numbers : Array(DWARF::LineNumbers::Row)

      def initialize
        @low_pc = 0
        @high_pc = 0
        @func_name = ""
        @line_numbers = [] of DWARF::LineNumbers::Row
      end

      def initialize(@low_pc, @high_pc, @func_name)
        @line_numbers = [] of DWARF::LineNumbers::Row
      end

      def contains(addr)
        @low_pc <= addr && addr <= @high_pc
      end

      def addLine(line : DWARF::LineNumbers::Row)
        return if line.end_sequence
        line_numbers << line
      end

      def inspect(io : IO) : Void
        io << "0x#{@low_pc.to_s(16)}-0x#{@high_pc.to_s(16)} (0x#{(@high_pc - @low_pc).to_s(16)}): #{@func_name}\n"
        io << "\tLines:\n"
        @line_numbers.each do |line|
          io << "\t\t0x#{(line.address).to_s(16)}: #{!line.directory.empty? ? line.directory + "/" + line.file : "none"}:#{line.line}:#{line.column}\n"
        end
      end
    end

    property dwarf_line_numbers : Array(DWARF::LineNumbers::Row)
    property strings : DWARF::Strings?
    property function_names : Array(ProcEntry)
    property base_address : UInt64

    def self.open(filename)
      self.new(filename)
    end

    def initialize(filename, @base_address : UInt64 = 0x100000000)
      file = File.open(filename, "r")
      file.seek(0, IO::Seek::End)
      size = file.pos
      file.seek(0, IO::Seek::Set)
      puts "Size is #{size}"
      buf = Bytes.new(size)
      file.read_fully(buf)
      @dwarf_macho = MachO.new(buf.to_a)
      @function_names = [] of ProcEntry
      @dwarf_line_numbers = [] of DWARF::LineNumbers::Row
    end

    def read
      Benchmark.measure("Read and parse .debug_line") do
        @dwarf_macho.read_section?("__debug_line") do |sh, io|
          line_numbers = DWARF::LineNumbers.new(io, sh.size)
          line_numbers.matrix.each do |row|
            row.each do |subRow|
              line = DWARF::LineNumbers::Row.new subRow.address - 0x100000000 + @base_address,
                subRow.op_index,
                subRow.directory,
                subRow.file,
                subRow.line,
                subRow.column,
                subRow.end_sequence
              dwarf_line_numbers << line
            end
          end
        end
      end

      @strings = @dwarf_macho.read_section?("__debug_str") do |sh, io|
        DWARF::Strings.new(io, sh.offset, sh.size)
      end

      @dwarf_macho.read_section?("__debug_info") do |sh, io|
        nameList = [] of String

        while (offset = io.pos - sh.offset) < sh.size
          info = DWARF::Info.new(io, offset)
          pp! "===> Initial Info: ", info

          @dwarf_macho.read_section?("__debug_abbrev") do |sh, io|
            info.read_abbreviations(io)
          end

          pp! "===> Info: ", info

          parse_function_names_from_dwarf(info, @base_address) do |low_pc, high_pc, name|
            procEntry = ProcEntry.new low_pc, high_pc, name
            dwarf_line_numbers.each do |line|
              if procEntry.contains line.address
                procEntry.addLine line
              end
            end
            @function_names << procEntry
          end
        end

        puts "===> Function Names: #{function_names}"
      end
    end

    def parse_function_names_from_dwarf(info, @base_address)
      info.each do |code, abbrev, attributes|
        next unless abbrev && abbrev.tag.subprogram?
        name = low_pc = high_pc = nil

        # pp! code, abbrev, attributes

        attributes.each do |(at, form, value)|
          puts "Attr: AT=#{at}, form=#{form}, value=#{getValue(value, form)}"
          case at
          when DWARF::AT::DW_AT_name
            value = @strings.try(&.decode(value.as(UInt32 | UInt64))) if form.strp?
            name = value.as(String)
          when DWARF::AT::DW_AT_low_pc
            low_pc = value.as(LibC::SizeT) - 0x100000000 + @base_address
          when DWARF::AT::DW_AT_high_pc
            if form.addr?
              high_pc = value.as(LibC::SizeT) - 0x100000000 + @base_address
            elsif value.responds_to?(:to_i)
              high_pc = low_pc.as(LibC::SizeT) + value.to_i
            end
          end
        end

        if low_pc && high_pc && name
          yield low_pc, high_pc, name
        end
      end
    end

    def getValue(value, form)
      form.strp? ? @strings.try(&.decode(value.as(UInt32 | UInt64))) : value
    end

    def parse_attributes_from_dwarf(info)
      info.each do |code, abbrev, attributes|
        next unless abbrev && abbrev.tag.subprogram?
        name = low_pc = high_pc = nil

        pp! code, abbrev, attributes

        attributes.each do |(at, form, value)|
          puts "Attr: AT=#{at}, form=#{form}, value=#{getValue(value, form)}"
          case at
          when DWARF::AT::DW_AT_name
            value = @strings.try(&.decode(value.as(UInt32 | UInt64))) if form.strp?
            name = value.as(String)
          when DWARF::AT::DW_AT_low_pc
            low_pc = value.as(LibC::SizeT) - 0x100000000 + @base_address
          when DWARF::AT::DW_AT_high_pc
            if form.addr?
              high_pc = value.as(LibC::SizeT) - 0x100000000 + @base_address
            elsif value.responds_to?(:to_i)
              high_pc = low_pc.as(LibC::SizeT) + value.to_i
            end
          end
        end

        if low_pc && high_pc && name
          yield low_pc, high_pc, name
        end
      end
    end
  end
end
