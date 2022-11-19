# BrokenFlow
A simple PoC to invoke an encrypted shellcode by using an hidden call.

## Introduction
This code uses a simple trick **to hide the instruction that effectively will jump to our shellcode**. This should make the static analysis or emulation more challenging.

As always, if this concept was already explained in some other papers just send me a message and I will happily add it to the references.

# Details
The memory layout to use this technique is the standard one and descrybed in Figure 1.

        ┌───────────────────────────────┐
        │                               │
        │                               │
        │                               │
        │                               │
        │   encrypted shellcode         │
        │                               │
        │                               │
        │                               │
        │                               │
        │                               │
        │                               │
        ├───────────────────────────────┤
        │                               │
        │                               │
        │  decryption loop              │
        │                               │
        │                               │
        └───────────────────────────────┘

Figure1. Memory Layout

The decryption loop will decrypt the shellcode and jump to it. All the "magic" is inside the decryption loop, since after finished decrypting the shellcode, the decryption loop will start to decrypt its own code. The decryption of the first instruction will result in a jump to our shellcode that is executed at the next loop iteration :)

Below the relevant part:

    @decryption:
    xor word ptr [eax], 06799h ; <jmp esi bytes> XOR <first two bytes of this instruction>
    add eax, sizeof word
    dec ecx
    loop @decryption
    
As you can see, **the decryption loop does not contain any instruction that jumps to the decrypted shellcode**. The assembly code is assembled in the following binary format:

    66:8130 9967             | xor word ptr ds:[eax],6799                                 
    83C0 02                  | add eax,2                                                    
    49                       | dec ecx                                                      
    E2 F5                    | loop 450006
    
in this case, the decryption key **must be 06799h**, since the XOR operation between 8166h (the first two bytes of the first instruction of the decryption loop) and 6799h (the XOR key) is e6ffh which is assembled to **jmp esi**. In other words:

    0x8166 (xor word ptr ds:[eax],...) XOR 0x6799 (decryption key) == 0x6eff (jmp esi)

By setting the ESI register to the start of our shellcode, we can achieve execution :)

Below an example of debugging. Initially the encrypted shellcode is copied, followed by the code used to decrypt and call the shellcode. It is possible to notice that after the third execution of the decryption loop, the instruction **xor word ptr ds:[eax],6799** changes to **jmp esi**.

![BrokenFlow execution](BrokenFlow.gif "BrokenFlow execution")

# Usage
The steps to use this technique are:
* Encrypt your shellcode with the XOR key 0x6799. The encryption loop iteration must have a WORD size step (2-bytes);
* Create the memory layout as reported in Figure 1. The encrypted shellcode size must be a multiple of two;
* Set the register ECX to the size of the allocated memory;
* Set register ESI to the start of the allocated memory (this address contains the shellcode to execute);
* Call the shellcode decryption code

# Possible Improvements
In order to make the decryption code less identifiable, it is possible to use alternative methods to call the shellcode. In order to have more freedom we can consider to increase the chunk size that is encrypted during each iteration. In my PoC I used 2-bytes becasuse **jmp esi** needs two bytes, but we can use 4 or 8-bytes chunk size, allowing the operator to have more alternatives that fit in 4 or 8-bytes chunk. According to the chosen way to call the shellcode, the encryption constant will change as well.
