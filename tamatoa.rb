# Tamatoa: Assemble 64bit MachOs
require "macho"
assembly = ""
# Clang - AT&T Syntax
ASSEMBLY_HEADER=<<EOF
.section __TEXT,__text
.globl _main
_main:
EOF
assembly << ASSEMBLY_HEADER
stager = File.read(ARGV[0]).bytes
# MMap RWX Anonymous and Private
STAGE_HEADER=<<EOF
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
assembly << STAGE_HEADER
# movl stager into memory
len = 0
stager.each_slice(4) do |s|
  s.compact!
  #STDERR.puts s.inspect
  #STDERR.puts s.pack("C*").inspect#.unpack("L")[0].inspect
  s = s.pack("C*").reverse.unpack("H*")[0]
  #STDERR.puts([s.to_i(16)].pack("L"))
  unless s == "00000000" # Memory is already zeroed out.
    assembly << "  addq $0x#{len.to_s(16)}, %r11\n" unless len == 0
    assembly << "  movl $0x#{s}, (%r11)\n"
    len = 0
  end
  len += 4
end
macho = File.read(ARGV[1]).bytes
# MMap RWX Anonymous and Private
MACH_HEADER=<<EOF
  movq $0x#{macho.size.to_s(16)}, %r12
  movq %r12, %rsi
  movq $7, %rdx
  movq $0x1002, %r10
  movl $0x20000c5, %eax
  syscall
  movq %rax, %r15
  movq %r15, %r11
EOF
assembly << MACH_HEADER
# movl macho into memory
len = 0
macho.each_slice(4) do |s|
  s.compact!
  s = s.pack("C*").reverse.unpack("H*")[0]
  unless s == "00000000" # Memory is already zeroed out.
    assembly << "  addq $0x#{len.to_s(16)}, %r11\n" unless len == 0
    assembly << "  movl $0x#{s}, (%r11)\n"
    len = 0
  end
  len += 4
end
# Push r14 onto stack (Gets clobbered by stager)
# Call stager entrypoint
# Restore r14 from top of stack
# MUnmap stager
# MUnmap macho
# exit 0
ASSEMBLY_FOOTER=<<EOF
  movq $0x#{MachO::MachOFile.new(ARGV[0]).load_commands.select {|l| l.class == MachO::LoadCommands::EntryPointCommand }[0].entryoff.to_s(16)}, %r11
  addq %r14, %r11

  pushq %r14

  callq *%r11

  popq %rdi
  movq $0x#{macho.size.to_s(16)}, %rsi
  movl $0x2000049, %eax
  syscall

  movq %r15, %rdi
  movq $0x#{stager.size.to_s(16)}, %rsi
  movl $0x2000049, %eax
  syscall

  xorq %rdi, %rdi
  movl $0x2000001, %eax
  syscall
EOF
assembly << ASSEMBLY_FOOTER
puts assembly
