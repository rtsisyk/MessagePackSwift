struct Encoder {
    private var buf: UnsafeMutablePointer<UInt8>
    private var wpos: UnsafeMutablePointer<UInt8>
    private var capacity: Int

    init() {
        capacity = 128
        buf = UnsafeMutablePointer<UInt8>(allocatingCapacity: capacity)
        wpos = buf
    }

    mutating func ensure(_ size: Int) -> UnsafeMutablePointer<UInt8> {
        let used = wpos - buf
        if (used + size <= capacity) {
            return wpos
        }
        var newCapacity = capacity > 0 ? capacity : 4096;
        while used + size > newCapacity {
             newCapacity *= 2
        }
        let newBuf = UnsafeMutablePointer<UInt8>(allocatingCapacity: newCapacity)
        if (used > 0) {
            newBuf.initializeFrom(buf, count: used)
        }
        buf.deinitialize()
        buf = newBuf
        wpos = newBuf + used
        capacity = newCapacity
        return wpos
    }

    mutating func advance(_ size: Int) {
        wpos += size;
        assert(wpos <= self.buf + capacity, "advance <= ensure");
    }

    mutating func alloc(_ size: Int) -> UnsafeMutablePointer<UInt8> {
        let pos = ensure(size)
        wpos += size
        return pos
    }

    mutating func reset() {
        wpos = buf
    }

    func result() -> (buf: UnsafeMutablePointer<UInt8>,
                      end: UnsafeMutablePointer<UInt8>) {
        return (buf, wpos)
    }

    mutating func store(typecode value: UInt8) {
        let wpos = alloc(sizeof(UInt8))
        wpos[0] = value
    }

    mutating func store(_ value: UInt8) {
        let wpos = alloc(sizeof(UInt8))
        wpos[0] = value
    }

    mutating func store(_ value: Int8) {
        store(UInt8(bitPattern: value))
    }

    mutating func store(_ value: UInt16) {
        let wpos = alloc(sizeof(UInt16))
        UnsafeMutablePointer<UInt16>(wpos)[0] = value.byteSwapped
    }

    mutating func store(_ value: Int16) {
        store(UInt16(bitPattern: value))
    }

    mutating func store(_ value: UInt32) {
        let wpos = alloc(sizeof(UInt32))
        UnsafeMutablePointer<UInt32>(wpos)[0] = value.byteSwapped
    }

    mutating func store(_ value: Int32) {
        store(UInt32(bitPattern: value))
    }

    mutating func store(_ value: UInt64) {
        let wpos = alloc(sizeof(UInt64))
        UnsafeMutablePointer<UInt64>(wpos)[0] = value.byteSwapped
    }

    mutating func store(_ value: Int64) {
        store(UInt64(bitPattern: value))
    }

    mutating func encode(_ value: UInt8) {
        print("encode_u8 \(value)")
        if (value <= 0x7f) {
            store(typecode: value)
        } else {
            store(typecode: 0xcc)
            store(value)
        }
    }

    mutating func encode(_ value: UInt16) {
        print("encode_u16 \(value)")
        if (value <= 0xff) {
            return encode(UInt8(truncatingBitPattern: value))
        }
        store(UInt8(0xcd))
        store(value)
    }

    mutating func encode(_ value: UInt32) {
        print("encode_u32 \(value)")
        if (value <= 0xffff) {
            return encode(UInt16(truncatingBitPattern: value))
        }
        store(UInt8(0xce))
        store(value)
    }

    mutating func encode(_ value: UInt64) {
        print("encode_u64 \(value)")
        if (value <= 0xffff_ffff) {
            return encode(UInt32(truncatingBitPattern: value))
        }
        store(UInt8(0xcd))
        store(value)
    }

    mutating func encode(_ value: UInt) {
        encode(UInt64(value))
    }

    mutating func encode(_ value: Int8) {
        print("encode_i8 \(value)")
        if value >= 0 {
            return encode(UInt8(bitPattern: value))
        } else if (value >= -0x20) {
            store(typecode: 0xe0 + 0x1f & UInt8(bitPattern: value))
        } else {
            store(typecode: 0xd0)
            store(value)
        }
    }

    mutating func encode(_ value: Int16) {
        print("encode_i16 \(value)")
        if (value >= 0) {
            return encode(UInt16(bitPattern: value))
        } else if (value >= -0x7f) {
             return encode(Int8(truncatingBitPattern: value))
        } else {
            store(typecode: 0xd1)
            store(value)
        }
    }

    mutating func encode(_ value: Int32) {
        print("encode_i32 \(value)")
        if (value >= 0) {
            return encode(UInt32(bitPattern: value))
        } else if (value >= -0x7fff) {
            return encode(Int16(truncatingBitPattern: value))
        } else {
            store(typecode: 0xd2)
            store(value)
        }
    }

    mutating func encode(_ value: Int64) {
        print("encode_i64 \(value)")
        if (value >= 0) {
            return encode(UInt64(bitPattern: value))
        } else if (value >= -0x7fff_ffff) {
            return encode(Int32(truncatingBitPattern: value))
        } else {
            store(typecode: 0xd3)
            store(value)
        }
    }

    mutating func encode(_ value: Int) {
        return encode(Int64(value))
    }

    mutating func encode(arrayHeader count: Int) {
        precondition(count <= 0xffff_ffff)
        switch count {
        case let count where count <= 0xe:
            store(UInt8(0x90 | count))
        case let count where count <= 0xffff:
            store(UInt8(0xdc))
            store(UInt16(count))
        default:
            store(UInt8(0xdd))
            store(UInt32(count))
        }
    }

    /**
     * Optimized version for Array<Int>
     */
    mutating func encode(_ array: Array<Int>) {
        encode(arrayHeader: array.count)
        for v in array {
            encode(v)
        }
    }

    mutating func encode<Type>(_ array: Array<Type>) {
        encode(arrayHeader: array.count)
        for v in array {
            encode(v)
        }
    }

    mutating func encode<Any>(_ value: Any) {
        print("encode_any: \(value)")
        switch value {
        case let u16 as UInt16:
            encode(u16)
        case let u32 as UInt32:
            encode(u32)
        case let u64 as UInt64:
            encode(u64)
        case let i16 as Int16:
            encode(i16)
        case let i32 as Int32:
            encode(i32)
        case let i64 as Int64:
            encode(i64)
        case let ii as Int:
            encode(Int64(ii))
        default:
            print("UnsupportedType");
            ///throw MessagePackError.UnsupportedType
        }
    }
};
