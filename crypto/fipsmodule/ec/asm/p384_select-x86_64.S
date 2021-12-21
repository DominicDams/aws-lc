/*
 * Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
 *
 * Licensed under the Apache License, Version 2.0 (the "License").
 * You may not use this file except in compliance with the License.
 * A copy of the License is located at
 *
 *  http://aws.amazon.com/apache2.0
 *
 * or in the "LICENSE" file accompanying this file. This file is distributed
 * on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either
 * express or implied. See the License for the specific language governing
 * permissions and limitations under the License.
 */

// ----------------------------------------------------------------------------
// 384-bit implementation of fiat select point using intel's avx-512
// Inputs out[3], idx, table[][3], table_size
//
//	extern void fiat_p384_select_point_avx512
//   (fiat_p384_felem out[3], size_t idx, fiat_p384_felem table[][3],
//   size_t table_size)
//
//Here we are making a lot of use of the fiat_p384_felem typedef which will be
//repeated here for reference
//  #define FIAT_P384_NLIMBS 6
//  typedef uint64_t fiat_p384_felem[FIAT_P384_NLIMBS];
//So out is actually 18 64 bit words
//and table is table_size sets of 18 64 bit words

        .intel_syntax noprefix
        .globl  fiat_p384_select_point_avx512
        .text
#define out rdi
#define idx rsi
#define table rdx
#define table_size rcx
#define index rax
#define buffer1 zmm0
#define buffer2 zmm1
#define buffer3 zmm2
#define mask k1
#define tmpmask r8d
#define mask_const r9d
#define offset r10

fiat_p384_select_point_avx512:
//Constant used to bitmask the words we want when doing our moves
//I'm using it because CMOV doesn't seem to work with literals
//We need to mask each 64 bit word (leading to a mask of b111111=0x3F)
mov mask_const, 0x0000003F
//Zeroize index
xor index, index
xor offset, offset

//We need to repeat our process for each table entry
loop:
cmp index, table_size
jae end

//do the bitmasked read
xor tmpmask, tmpmask
cmp index, idx
cmove tmpmask, mask_const
kmovw mask, tmpmask
//The actual read
//Since the table is laid out in memory as:
//groups of three "points"
//Which are each 6 words
//Which are each 8 bytes
//We need to multiply the index by 3*6*8=144 to get the proper offset
//And offset each read by 8*6=48
vmovdqu64 buffer1 {mask}, [table + offset]
vmovdqu64 buffer2 {mask}, [table + offset + 48]
vmovdqu64 buffer3 {mask}, [table + offset + 96]

//increment the index
inc index
//We need this to properly offset from the table.
add offset, 0x90
jmp loop
//Copy the data from the buffer
end:
kmovw mask, mask_const
vmovdqu64 [out] {mask}, buffer1
vmovdqu64 [out + 48] {mask}, buffer2
vmovdqu64 [out + 96] {mask}, buffer3

ret


#if defined(__linux__) && defined(__ELF__)
.section .note.GNU-stack,"",%progbits
#endif
