#!/usr/bin/env ruby
assembly = ""
ASSEMBLY_HEADER=<<EOF
.section __TEXT,__text
.globl _main
_main:
EOF
assembly << ASSEMBLY_HEADER
stager = File.read(ARGV[0]).bytes
BYTE_HEADER=<<EOF
  xorq %r8, %r8
  xorq %r9, %r9
  movq $0x#{stager.size.to_s(16)}, %rsi
  movq $7, %rdx
  movq $0x1002, %r10
  movl $0x20000c5, %eax
  syscall
  movq %rax, %r14
  movq %r14, %r11
EOF
assembly << BYTE_HEADER
len = 0
stager.each_slice(4) do |s|
  s.compact!
  #STDERR.puts s.inspect
  #STDERR.puts s.pack("C*").inspect#.unpack("L")[0].inspect
  s = s.pack("C*").reverse.unpack("H*")[0]
  #STDERR.puts([s.to_i(16)].pack("L"))
  unless s == "00000000"
    assembly << "  addq $0x#{len.to_s(16)}, %r11\n" unless len == 0
    assembly << "  movl $0x#{s}, (%r11)\n"
    len = 0
  end
  len += 4
end
macho = File.read(ARGV[1]).bytes
PAYLOAD_HEADER=<<EOF
  movq $0x#{macho.size.to_s(16)}, %r12
  movq $#{macho.size}, %rsi
  movq $7, %rdx
  movq $0x1002, %r10
  movl $0x20000c5, %eax
  syscall
  movq %rax, %r10
  movq %r10, %r11
EOF
assembly << PAYLOAD_HEADER
len = 0
macho.each_slice(4) do |s|
  s.compact!
  s = s.pack("C*").reverse.unpack("H*")[0]
  unless s == "00000000"
    assembly << "  addq $0x#{len.to_s(16)}, %r11\n" unless len == 0
    assembly << "  movl $0x#{s}, (%r11)\n"
    len = 0
  end
  len += 4
end
ASSEMBLY_FOOTER=<<EOF
  andq $-0x10, %rsp
  pushq $0
  pushq $0
  pushq $0
  movq $0, %rax
  pushq %rax

  movq $15527, %rax
  add %rax, %r14

  callq *%r14

  movq %r10, %r8
  movq $0x#{stager.size.to_s(16)}, %r9
  movl $0x2000049, %eax
  syscall

  movq %r14, %r8
  movq $0x#{macho.size.to_s(16)}, %r9
  movl $0x2000049, %eax
  syscall

  movl $0x2000001, %eax
  movq $0x0, %rdi
  syscall
EOF
assembly << ASSEMBLY_FOOTER
puts assembly
