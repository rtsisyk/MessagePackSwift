var encoder = Encoder()
let value: Array<Any> = [UInt32(1), UInt64(2), "Hello", 3]
let value2: Array<Int> = [1, 2, 3]
encoder.encode(value2)
let result = encoder.result()
print("writer.wpos: \(result.buf, result.end)")

#if false
let arr: [UInt8] = [1, 2, 3, 4]
let buf = UnsafeMutablePointer<UInt8>(arr)
let x: UInt32 = 33;
x.store(buf)
var p = UnsafePointer<UInt8>(buf)
decode(&p)
print("buf \(buf) \(p)")
let y = UInt32.load(buf)
print("y = \(y)")
print("addr \(buf[0]), \(buf[1]), \(buf[2]), \(buf[3])")
#endif
