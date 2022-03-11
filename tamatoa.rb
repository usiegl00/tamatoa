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
# Clear Registers
# MMap RWX Anonymous and Private
# Store Return Address in r14
STAGE_HEADER=<<EOF
  xorq %r8, %r8
  xorq %r9, %r9
  xorq %rdi, %rdi
EOF
assembly << STAGE_HEADER
macho = File.read(ARGV[0]).bytes
# MMap RWX Anonymous and Private
# TODO: 1407...???
MACH_HEADER=<<EOF
  movq $0x7f0000000000, %rdi
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
# MUnmap macho
# exit 0
ASSEMBLY_FOOTER=<<EOF
  pushq %r15

  callq _stage

  popq %r15
  movq %r15, %rdi
  movq $0x#{macho.size.to_s(16)}, %rsi
  movl $0x2000049, %eax
  syscall

  xorq %rdi, %rdi
  callq _fflush

  xorq %rdi, %rdi
  movl $0x2000001, %eax
  syscall
EOF
assembly << ASSEMBLY_FOOTER
# Stager
ASSEMBLY_STAGER_HEADER=<<EOF
_stage:
  pushq %rbp
  movq %rsp, %rbp
  subq $0x50, %rsp
  movq %r15, 0x10(%rsp)
  movq %r12, 0x18(%rsp)
  xorq %rcx, %rcx
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

  addq $0x#{(MachO::MachOFile.new(ARGV[0]).load_commands.select {|l|l.class == MachO::LoadCommands::EntryPointCommand}[0].entryoff.to_s(16))}, %rsi
  movq %rsi, %r10
EOF
assembly << ASSEMBLY_STAGER_HEADER
# Handle arguments
rpop = 0
arguments = ARGV[1..-1].empty? ? ["./."] : ARGV[1..-1]
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
  xorq %r12, %r12
  xorq %r13, %r13
  xorq %r14, %r14
  xorq %rdx, %rdx
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
  add %r12, %rbx
  movq (%rsp), %rdx
  movl 0x10(%rdx), %edi
  addq %rdi, %rbx
  movq %rbx, 0x40(%rsp)
  movq (%rsp), %rdx
  xorq %rax, %rax
  movl 0xC(%rdx), %eax
  decq %rax
  movq 0x30(%rsp), %rbx
  movq %r12, %r8
  addl 0x8(%rdx), %r8d
  addq %rbx, %r8
  xorq %rcx, %rcx
_gvloop:
  movq 0x40(%rsp), %rdi
  movl (%r8, %rcx, 8), %r11d
  addq %r11, %rdi
  xorq %r13, %r13
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
  inc %rcx
  cmpq %rax, %rcx
  jl _gvloop
  movq $-0x1, %rax
  addq $0x50, %rsp
  popq %rbp
  retq

__fwalk:
  pushq %rbp
  movq %rsp, %rbp
  pushq %r15
  pushq %r14
  pushq %r13
  pushq %r12
  pushq %rbx
  pushq %rax
  movq %rdi, %r14
  movq 367(%rip), %r12
  xorl %r15d, %r15d
  testq %r12, %r12
  je __fwalk+0x53
  movq 16(%r12), %rbx
  movl 8(%r12), %r13d
  testl %r13d, %r13d
  jle __fwalk+0x4d
  cmpw $0, 16(%rbx)
  je __fwalk+0x41
  movq %rbx, %rdi
  xorl %eax, %eax
  callq *%r14
  orl %eax, %r15d
  decl %r13d
  addq $152, %rbx
  jmp __fwalk+0x2a
  movq (%r12), %r12
  jmp __fwalk+0x1b
  movl %r15d, %eax
  addq $8, %rsp
  popq %rbx
  popq %r12
  popq %r13
  popq %r14
  popq %r15
  popq %rbp
  retq

___sflush:
  pushq %rbp
  movq %rsp, %rbp
  pushq %r15
  pushq %r14
  pushq %rbx
  pushq %rax
  movswl 16(%rdi), %ecx
  xorl %eax, %eax
  testb $8, %cl
  je ___sflush+0x63
  movq %rdi, %r14
  movq 24(%rdi), %r15
  testq %r15, %r15
  je ___sflush+0x63
  movl (%r14), %ebx
  movq %r15, (%r14)
  xorl %eax, %eax
  testb $3, %cl
  jne ___sflush+0x32
  movl 32(%r14), %eax
  subl %r15d, %ebx
  movl %eax, 12(%r14)
  testl %ebx, %ebx
  jle ___sflush+0x57
  movq 48(%r14), %rdi
  movq %r15, %rsi
  movl %ebx, %edx
  callq *80(%r14)
  testl %eax, %eax
  jle ___sflush+0x5b
  subl %eax, %ebx
  movl %eax, %eax
  addq %rax, %r15
  jmp ___sflush+0x39
  xorl %eax, %eax
  jmp ___sflush+0x63
  orb $64, 16(%r14)
  pushq $-1
  popq %rax
  addq $8, %rsp
  popq %rbx
  popq %r14
  popq %r15
  popq %rbp
  retq

_fflush:
  pushq %rbp
  movq %rsp, %rbp
  testq %rdi, %rdi
  je _fflush+0x15
  testb $24, 16(%rdi)
  je _fflush+0x22
  popq %rbp
  jmp ___sflush
  leaq -138(%rip), %rdi
  popq %rbp
  jmp __fwalk
  callq 19 #dyld_stub_binder+0x100003f86
  movl $9, (%rax)
  pushq $-1
  popq %rax
  popq %rbp
  retq
EOF
assembly << ASSEMBLY_STAGER_FOOTER
puts assembly
