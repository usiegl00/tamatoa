# Tamatoa: Assemble x86_64 MachOs
require "macho"
assembly = ""
# Clang - AT&T Syntax
ASSEMBLY_HEADER=<<EOF
.text
.globl _main
_main:
EOF
assembly << ASSEMBLY_HEADER
# Load swift
if ARGV[0] != ARGV[2]
swift = File.read(ARGV[2]).bytes
MACH_HEADER_SWIFT=<<EOF
  xorq %r8, %r8
  xorq %r9, %r9
  xorq %rdi, %rdi
  movq $0x#{swift.size.to_s(16)}, %r12
  movq %r12, %rsi
  movl $7, %edx
  movl $0x1002, %r10d
  movl $0x20000c5, %eax
  syscall
  movq %rax, %r15
  movq %r15, %r11
EOF
assembly << MACH_HEADER_SWIFT
# movl swift into memory
len = 0
swift.each_slice(4) do |s|
  s.compact!
  s = s.pack("C*").reverse.unpack("H*")[0]
  unless s == "00000000" # Memory is already zeroed out.
    assembly << "  addq $0x#{len.to_s(16)}, %r11\n" unless len == 0
    assembly << "  movl $0x#{s}, (%r11)\n"
    len = 0
  end
  len += 4
end
ASSEMBLY_FOOTER_SWIFT=<<EOF
  pushq %r15

  movq $0x#{(MachO::MachOFile.new(ARGV[2]).load_commands.select {|l|l.class == MachO::LoadCommands::EntryPointCommand}[0].entryoff.to_s(16))}, %r14
  callq _stage

  popq %r15
  movq %r15, %rdi
  movq $0x#{swift.size.to_s(16)}, %rsi
  movl $0x2000049, %eax
  syscall
EOF
assembly << ASSEMBLY_FOOTER_SWIFT
end
# Clear Registers
# MMap RWX Anonymous and Private
# Store Return Address in r14
STAGE_HEADER=<<EOF
  xorq %r8, %r8
  xorq %r9, %r9
  #xorq %rdi, %rdi
EOF
assembly << STAGE_HEADER
macho = File.read(ARGV[0]).bytes
# MMap RWX Anonymous and Private
# TODO: 1407...???
MACH_HEADER=<<EOF
  xorq %rdi, %rdi
  movq $0x#{macho.size.to_s(16)}, %r12
  movq %r12, %rsi
  movl $7, %edx
  movl $0x1002, %r10d
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
# Push r15 onto stack (Gets clobbered by stager)
# Call stager entrypoint
# Restore r15 from top of stack
# MUnmap macho
# exit 0
ASSEMBLY_FOOTER=<<EOF
  pushq %r15

  movq $0x#{(MachO::MachOFile.new(ARGV[0]).load_commands.select {|l|l.class == MachO::LoadCommands::EntryPointCommand}[0].entryoff.to_s(16))}, %r14
  callq _stage

  popq %r15
  movq %r15, %rdi
  movq $0x#{macho.size.to_s(16)}, %rsi
  movl $0x2000049, %eax
  syscall
EOF
assembly << ASSEMBLY_FOOTER
# Load fflush
if ARGV[0] != ARGV[1]
fflush = File.read(ARGV[1]).bytes
MACH_HEADER_FFLUSH=<<EOF
  xorq %r8, %r8
  xorq %r9, %r9
  xorq %rdi, %rdi
  movq $0x#{fflush.size.to_s(16)}, %r12
  movq %r12, %rsi
  movl $7, %edx
  movl $0x1002, %r10d
  movl $0x20000c5, %eax
  syscall
  movq %rax, %r15
  movq %r15, %r11
EOF
assembly << MACH_HEADER_FFLUSH
# movl fflush into memory
len = 0
fflush.each_slice(4) do |s|
  s.compact!
  s = s.pack("C*").reverse.unpack("H*")[0]
  unless s == "00000000" # Memory is already zeroed out.
    assembly << "  addq $0x#{len.to_s(16)}, %r11\n" unless len == 0
    assembly << "  movl $0x#{s}, (%r11)\n"
    len = 0
  end
  len += 4
end
ASSEMBLY_FOOTER_FFLUSH=<<EOF
  pushq %r15

  movq $0x#{(MachO::MachOFile.new(ARGV[1]).load_commands.select {|l|l.class == MachO::LoadCommands::EntryPointCommand}[0].entryoff.to_s(16))}, %r14
  callq _stage

  popq %r15
  movq %r15, %rdi
  movq $0x#{fflush.size.to_s(16)}, %rsi
  movl $0x2000049, %eax
  syscall
EOF
assembly << ASSEMBLY_FOOTER_FFLUSH
end
ASSEMBLY_EXIT=<<EOF
  xorq %rdi, %rdi
  movl $0x2000001, %eax
  syscall
EOF
assembly << ASSEMBLY_EXIT
# Stager
ASSEMBLY_STAGER_HEADER=<<EOF
_stage:
  pushq %rbp
  movq %rsp, %rbp
  subq $0x50, %rsp
  movq %r14, 0x8(%rsp)
  movq %r15, 0x10(%rsp)
  movq %r12, 0x18(%rsp)
  xorq %rcx, %rcx
  xorq %rsi, %rsi
  movq $0x1000, %rdx
  movq $0x100000000, %rdi
  callq _finddyld
_dyld:
  xorq %rcx, %rcx
  movq $0x1000, %rdx
  addq $0x1000, %rsi
  movq %rsi, %rdi
  callq _finddyld
  movq %rsi, 0x20(%rsp)
_nscreate:
  movq 0x20(%rsp), %rdx
  movq $0x19, %rsi
  movq $0x4d6d6f72, %rdi
  callq _resolvesymbol
  movq %rax, 0x28(%rsp)
  cmpq $-0x1, %rax
  je _fdyld
_nsmodule:
  movq 0x20(%rsp), %rdx
  movq $0x4, %rsi
  movq $0x4d6b6e69, %rdi
  callq _resolvesymbol
  movq %rax, 0x30(%rsp)
  movq 0x10(%rsp), %rdi
  movl $0x8, 0xC(%rdi)
  movq 0x18(%rsp), %rsi
  leaq 0x38(%rsp), %rdx
  movq 0x28(%rsp), %rax
  callq *%rax
  testb %al, %al
  jz _exit

  movq 0x38(%rsp), %rdi
  movw $0x6d, 0x40(%rsp)
  leaq 0x40(%rsp), %rsi
  movl $0x3, %edx
  movq 0x30(%rsp), %rax
  callq *%rax
  movq %rax, %rdi
  xorq %rsi, %rsi
  movq $0x8, %rdx
  movq $1, %rcx
  callq _finddyld
  cmpq $0x0, %rsi
  je _exit

  addq 0x8(%rsp), %rsi
  movq %rsi, %r10
EOF
assembly << ASSEMBLY_STAGER_HEADER
# Handle arguments
rpop = 0
arguments = ARGV[3..-1].empty? ? ["./."] : ARGV[3..-1]
(arguments.count+1).times do
  assembly << "  pushq $0\n"
  rpop += 1
end
assembly << "  movq %rsp, %rsi\n"
arguments.each_with_index do |arg, i|
  assembly << "  pushq $0\n"
  rpop += 1
  "#{arg}#{"\x00"*(8-arg.size%8)}".unpack("Q*").reverse.each do |q|
    assembly << "  movq $#{q}, %rdi\n"
    assembly << "  pushq %rdi\n"
    rpop += 1
  end
  assembly << "  movq %rsp, #{8*i}(%rsi)\n"
end
assembly << "  movq $#{arguments.count}, %rdi\n"
assembly << "  callq *%r10\n" # Target _main
assembly << "  addq $#{rpop*8}, %rsp\n"
ASSEMBLY_STAGER_FOOTER=<<EOF
_exit:
  addq $0x50, %rsp
  popq %rbp
  retq

_fdyld:
  movq 0x20(%rsp), %rsi
  jmp _dyld

# Locates the dlyd in memory.
# Machine code will keep going if it reaches the end
# of a function without a retq or jmpq.
_finddyld:
  pushq %rbp
  movq %rsp, %rbp
  subq $0x20, %rsp
  movq %rdi, (%rsp)
  movq %rsi, 0x8(%rsp)
  movq %rdx, 0x10(%rsp)
  movq %rcx, 0x18(%rsp)
  movq (%rsp), %rbx
_fdloop0:
  movq 0x18(%rsp), %rcx
  cmpq $1, %rcx
  jne _fdcheck
  movq (%rbx), %rcx
  movq %rcx, %rdi
  jmp _fddref
_fdcheck:
  movq %rbx, %rdi
_fddref:
  movq $0x1ff, %rsi
  movq $0x200000F, %rax
  syscall
  xorq %rsi, %rsi
  cmpq $2, %rax
  jne _fdloop1
  movl (%rdi), %edx
  movl $0xfeedfacf, %eax
  cmpl %edx, %eax
  jne _fdloop1
  movq %rdi, 0x8(%rsp)
  jmp _fdexit
_fdloop1:
  add 0x10(%rsp), %rbx
  jmp _fdloop0
_fdexit:
  movq 0x8(%rsp), %rsi
  addq $0x20, %rsp
  popq %rbp
  retq

_resolvesymbol:
  pushq %rbp
  movq %rsp, %rbp
  subq $0x50, %rsp
  movq %rdi, 0x28(%rsp)
  movq %rdx, 0x30(%rsp)
  movq %rsi, 0x38(%rsp)
  movq 0x30(%rsp), %rbx
  movq %rbx, %r8
  addq $0x20, %r8
  movl 0x10(%rbx), %ecx
  decl %ecx
_rsloop:
  movl (%r8), %edx
  cmpl $0x2, %edx
  jne _rscont0
  movq %r8, (%rsp)
_rscont0:
  cmpl $0x19, %edx
  jne _rscont1
  movq %r8, 0x8(%rsp)
  movq %r8, %r11
  movq 0xA(%r8), %rdx
  cmpl $0x4b4e494c, %edx
  jne _case
  movq %r11, 0x10(%rsp)
  jmp _rscont1
_case:
  cmpl $0x54584554, %edx
  jne _rscont1
  movq %r11, 0x18(%rsp)
_rscont1:
  movl 0x4(%r8), %edx
  addq %rdx, %r8
  decq %rcx
  cmpq $0x0, %rcx
  jne _rsloop
  movq 0x10(%rsp), %r12
  cmpq $0x0, %r12
  jne _getvaddr
  movq $-0x1, %rax
  addq $0x50, %rsp
  popq %rbp
  retq

_getvaddr:
  xorq %rdi, %rdi
  xorq %rbx, %rbx
  movq 0x10(%rsp), %r12
  movl 0x18(%r12), %r12d
  movq 0x18(%rsp), %r13
  movl 0x18(%r13), %r13d
  movq 0x10(%rsp), %r14
  movl 0x28(%r14), %r14d
  subq %r13, %r12
  subq %r14, %r12
  movq %r12, 0x20(%rsp)
  movq 0x30(%rsp), %rbx
  addq %r12, %rbx
  movq (%rsp), %rdx
  movl 0x10(%rdx), %edi
  addq %rdi, %rbx
  movq %rbx, 0x40(%rsp)
  xorq %rax, %rax
  movl 0xC(%rdx), %eax
  decq %rax
  movq 0x30(%rsp), %rbx
  movq %r12, %r8
  addl 0x8(%rdx), %r8d
  addq %rbx, %r8
  xorq %rcx, %rcx
  movq 0x40(%rsp), %rdi
  movl (%r8, %rcx, 8), %r11d
  addq %r11, %rdi
#  callq _gvwrite
  movq (%rdi), %r13
  movq $8313473854205091679, %r14
  cmpq %r14, %r13
  jne _gvfail
  jmp _gvcontinue
_gvloop:
  movq 0x40(%rsp), %rdi
  movl (%r8, %rcx, 8), %r11d
  addq %r11, %rdi
#  callq _gvwrite
  movl 0x38(%rsp), %r13d
  movl 0x28(%rsp), %r14d
  addq %r13, %rdi
  movl (%rdi), %r13d
  cmpl %r14d, %r13d
  jne _gvcontinue
  leaq (%r8, %rcx, 8), %r11
  movq 0x8(%r11), %r11
  addq %r11, %rbx
  movq %rbx, %rax
  addq $0x50, %rsp
  popq %rbp
  retq
_gvcontinue:
  incq %rcx
  cmpq %rax, %rcx
  jl _gvloop
  movq $-0x1, %rax
  addq $0x50, %rsp
  popq %rbp
  retq
_gvfail:
  movq %rcx, %rax
  incq %rax
  jmp _gvcontinue
#_gvwrite:
#  pushq %rcx
#  pushq %rdx
#  pushq %rdi
#  pushq %rsi
#  pushq %rax
#  movq %rdi, %rsi
#  movq $30, %rdx
#  movq $1, %rdi
#  movl $0x2000004, %eax
#  syscall
#  popq %rax
#  popq %rsi
#  popq %rdi
#  popq %rdx
#  popq %rcx
#  retq
EOF
assembly << ASSEMBLY_STAGER_FOOTER
puts assembly
