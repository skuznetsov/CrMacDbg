require "./abbrev"

module DWARF
  struct Info
    property unit_length : UInt32 | UInt64
    property version : UInt16
    property debug_abbrev_offset : UInt32 | UInt64
    property address_size : UInt8
    property! abbreviations : Array(DWARF::Abbrev)

    property dwarf64 : Bool
    @offset : Int64
    @ref_offset : Int64

    def initialize(@io : IO::Memory, offset)
      @ref_offset = @offset = offset.to_i64

      @unit_length = @io.read_bytes(UInt32)
      if @unit_length == 0xffffffff
        @dwarf64 = true
        @unit_length = @io.read_bytes(UInt64)
      else
        @dwarf64 = false
      end

      @offset = @io.tell.to_i64
      @version = @io.read_bytes(UInt16)
      @debug_abbrev_offset = read_ulong
      @address_size = @io.read_byte.not_nil!
    end

    alias Value = Bool | Int32 | Int64 | Slice(UInt8) | String | UInt16 | UInt32 | UInt64 | UInt8

    def read_abbreviations(io)
      @abbreviations = DWARF::Abbrev.read(io, debug_abbrev_offset)
      #   pp! abbreviations
    end

    def each
      end_offset = @offset + @unit_length
      attributes = [] of {DWARF::AT, DWARF::FORM, Value}

      while @io.tell < end_offset
        code = DWARF.read_unsigned_leb128(@io)
        attributes.clear

        if abbrev = abbreviations[code &- 1]? # abbreviations.find { |a| a.code == abbrev }
          abbrev.attributes.each do |attr|
            value = read_attribute_value(attr.form)
            attributes << {attr.at, attr.form, value}
          end
          yield code, abbrev, attributes
        else
          yield code, nil, attributes
        end
      end
    end

    private def read_attribute_value(form)
      case form
      when DWARF::FORM::Addr
        case address_size
        when 4 then @io.read_bytes(UInt32)
        when 8 then @io.read_bytes(UInt64)
        else        raise "Invalid address size: #{address_size}"
        end
      when DWARF::FORM::Block1
        len = @io.read_byte.not_nil!
        @io.read_fully(bytes = Bytes.new(len.to_i))
        bytes
      when DWARF::FORM::Block2
        len = @io.read_bytes(UInt16)
        @io.read_fully(bytes = Bytes.new(len.to_i))
        bytes
      when DWARF::FORM::Block4
        len = @io.read_bytes(UInt32)
        @io.read_fully(bytes = Bytes.new(len.to_i64))
        bytes
      when DWARF::FORM::Block
        len = DWARF.read_unsigned_leb128(@io)
        @io.read_fully(bytes = Bytes.new(len))
        bytes
      when DWARF::FORM::Data1
        @io.read_byte.not_nil!
      when DWARF::FORM::Data2
        @io.read_bytes(UInt16)
      when DWARF::FORM::Data4
        @io.read_bytes(UInt32)
      when DWARF::FORM::Data8
        @io.read_bytes(UInt64)
      when DWARF::FORM::Sdata
        DWARF.read_signed_leb128(@io)
      when DWARF::FORM::Udata
        DWARF.read_unsigned_leb128(@io)
      when DWARF::FORM::Exprloc
        len = DWARF.read_unsigned_leb128(@io)
        @io.read_fully(bytes = Bytes.new(len))
        bytes
      when DWARF::FORM::Flag
        @io.read_byte == 1
      when DWARF::FORM::FlagPresent
        true
      when DWARF::FORM::SecOffset
        read_ulong
      when DWARF::FORM::Ref1
        @ref_offset + @io.read_byte.not_nil!.to_u64
      when DWARF::FORM::Ref2
        @ref_offset + @io.read_bytes(UInt16).to_u64
      when DWARF::FORM::Ref4
        @ref_offset + @io.read_bytes(UInt32).to_u64
      when DWARF::FORM::Ref8
        @ref_offset + @io.read_bytes(UInt64).to_u64
      when DWARF::FORM::RefUdata
        @ref_offset + DWARF.read_unsigned_leb128(@io)
      when DWARF::FORM::RefAddr
        read_ulong
      when DWARF::FORM::RefSig8
        @io.read_bytes(UInt64)
      when DWARF::FORM::String
        @io.gets('\0', chomp: true).to_s
      when DWARF::FORM::Strp
        read_ulong
      when DWARF::FORM::Indirect
        form = DWARF::FORM.new(DWARF.read_unsigned_leb128(@io))
        read_attribute_value(form)
      else
        raise "Unknown DW_FORM_#{form.to_s.underscore}"
      end
    end

    private def read_ulong
      if @dwarf64
        @io.read_bytes(UInt64)
      else
        @io.read_bytes(UInt32)
      end
    end
  end
end
