global main
section .text

main:
    push rbp
    mov rbp, rsp
    sub rsp, 4096
    mov qword [rbp-8], 100
    mov rax, qword [rbp-8]
    mov qword [rbp-16], rax
    mov qword [rbp-24], 200
    mov rax, qword [rbp-24]
    mov qword [rbp-32], rax
    mov rax, qword [rbp-16]
    mov qword [rbp-40], rax
    mov rax, qword [rbp-32]
    mov qword [rbp-48], rax
    mov rax, qword [rbp-40]
    mov rbx, qword [rbp-48]
    add rax, rbx
    mov qword [rbp-56], rax
    mov rax, qword [rbp-56]
    mov qword [rbp-64], rax
    mov rax, qword [rbp-64]
    mov qword [rbp-72], rax
    mov rax, qword [rbp-64]
    mov qword [rbp-80], rax
    mov rax, qword [rbp-72]
    mov rbx, qword [rbp-80]
    imul rax, rbx
    mov qword [rbp-88], rax
    mov rax, qword [rbp-88]
    mov qword [rbp-64], rax
    mov rax, qword [rbp-64]
    leave
    ret

section .data
