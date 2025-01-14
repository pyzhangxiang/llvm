# RUN: llvm-mc %s -triple=mips-unknown-linux -show-encoding -mcpu=mips32r6 -mattr=micromips -mattr=+dsp | FileCheck %s

  .set noat
  absq_s.ph $3, $4             # CHECK: absq_s.ph $3, $4        # encoding: [0x00,0x64,0x11,0x3c]
  absq_s.w $3, $4              # CHECK: absq_s.w $3, $4         # encoding: [0x00,0x64,0x21,0x3c]
  addu.qb $3, $4, $5           # CHECK: addu.qb $3, $4, $5      # encoding: [0x00,0xa4,0x18,0xcd]
  addu_s.qb $3, $4, $5         # CHECK: addu_s.qb $3, $4, $5    # encoding: [0x00,0xa4,0x1c,0xcd]
  addsc $3, $4, $5             # CHECK: addsc $3, $4, $5        # encoding: [0x00,0xa4,0x1b,0x85]
  addwc $3, $4, $5             # CHECK: addwc $3, $4, $5        # encoding: [0x00,0xa4,0x1b,0xc5]
  addq.ph $3, $4, $5           # CHECK: addq.ph $3, $4, $5      # encoding: [0x00,0xa4,0x18,0x0d]
  addq_s.ph $3, $4, $5         # CHECK: addq_s.ph $3, $4, $5    # encoding: [0x00,0xa4,0x1c,0x0d]
  addq_s.w $3, $4, $5          # CHECK: addq_s.w $3, $4, $5     # encoding: [0x00,0xa4,0x1b,0x05]
  dpaq_s.w.ph $ac1, $5, $3     # CHECK: dpaq_s.w.ph $ac1, $5, $3   # encoding: [0x00,0x65,0x42,0xbc]
  dpaq_sa.l.w $ac2, $4, $3     # CHECK: dpaq_sa.l.w $ac2, $4, $3   # encoding: [0x00,0x64,0x92,0xbc]
  dpau.h.qbl $ac1, $3, $4      # CHECK: dpau.h.qbl $ac1, $3, $4    # encoding: [0x00,0x83,0x60,0xbc]
  dpau.h.qbr $ac2, $20, $21    # CHECK: dpau.h.qbr $ac2, $20, $21  # encoding: [0x02,0xb4,0xb0,0xbc]
  extp $zero, $ac1, 6          # CHECK: extp $zero, $ac1, 6        # encoding: [0x00,0x06,0x66,0x7c]
  extpdp $2, $ac1, 2           # CHECK: extpdp $2, $ac1, 2         # encoding: [0x00,0x42,0x76,0x7c]
  extpdpv $4, $ac2, $8         # CHECK: extpdpv $4, $ac2, $8       # encoding: [0x00,0x88,0xb8,0xbc]
  extpv $15, $ac3, $7          # CHECK: extpv $15, $ac3, $7        # encoding: [0x01,0xe7,0xe8,0xbc]
  extr.w $27, $ac3, 31         # CHECK: extr.w $27, $ac3, 31       # encoding: [0x03,0x7f,0xce,0x7c]
  extr_r.w $12, $ac0, 24       # CHECK: extr_r.w $12, $ac0, 24     # encoding: [0x01,0x98,0x1e,0x7c]
  extr_rs.w $27, $ac3, 9       # CHECK: extr_rs.w $27, $ac3, 9     # encoding: [0x03,0x69,0xee,0x7c]
  extr_s.h $3, $ac2, 1         # CHECK: extr_s.h $3, $ac2, 1       # encoding: [0x00,0x61,0xbe,0x7c]
  extrv.w $5, $ac0, $6         # CHECK: extrv.w $5, $ac0, $6       # encoding: [0x00,0xa6,0x0e,0xbc]
  extrv_r.w $10, $ac0, $3      # CHECK: extrv_r.w $10, $ac0, $3    # encoding: [0x01,0x43,0x1e,0xbc]
  extrv_rs.w $15, $ac1, $20    # CHECK: extrv_rs.w $15, $ac1, $20  # encoding: [0x01,0xf4,0x6e,0xbc]
  extrv_s.h $8, $ac2, $16      # CHECK: extrv_s.h $8, $ac2, $16    # encoding: [0x01,0x10,0xbe,0xbc]
  insv $3, $4                  # CHECK: insv $3, $4             # encoding: [0x00,0x64,0x41,0x3c]
  madd $ac1, $6, $7            # CHECK: madd $ac1, $6, $7       # encoding: [0x00,0xe6,0x4a,0xbc]
  maddu $ac0, $8, $9           # CHECK: maddu $ac0, $8, $9      # encoding: [0x01,0x28,0x1a,0xbc]
  msub $ac3, $10, $11          # CHECK: msub $ac3, $10, $11     # encoding: [0x01,0x6a,0xea,0xbc]
  msubu $ac2, $12, $13         # CHECK: msubu $ac2, $12, $13    # encoding: [0x01,0xac,0xba,0xbc]
  mult $ac3, $2, $3            # CHECK: mult $ac3, $2, $3       # encoding: [0x00,0x62,0xcc,0xbc]
  multu $ac2, $4, $5           # CHECK: multu $ac2, $4, $5      # encoding: [0x00,0xa4,0x9c,0xbc]
  preceq.w.phl $1, $2          # CHECK: preceq.w.phl $1, $2      # encoding: [0x00,0x22,0x51,0x3c]
  preceq.w.phr $3, $4          # CHECK: preceq.w.phr $3, $4      # encoding: [0x00,0x64,0x61,0x3c]
  precequ.ph.qbl $5, $6        # CHECK: precequ.ph.qbl $5, $6    # encoding: [0x00,0xa6,0x71,0x3c]
  precequ.ph.qbla $7, $8       # CHECK: precequ.ph.qbla $7, $8   # encoding: [0x00,0xe8,0x73,0x3c]
  precequ.ph.qbr $9, $10       # CHECK: precequ.ph.qbr $9, $10   # encoding: [0x01,0x2a,0x91,0x3c]
  precequ.ph.qbra $11, $12     # CHECK: precequ.ph.qbra $11, $12 # encoding: [0x01,0x6c,0x93,0x3c]
  preceu.ph.qbl $13, $14       # CHECK: preceu.ph.qbl $13, $14   # encoding: [0x01,0xae,0xb1,0x3c]
  preceu.ph.qbla $15, $16      # CHECK: preceu.ph.qbla $15, $16  # encoding: [0x01,0xf0,0xb3,0x3c]
  preceu.ph.qbr $17, $18       # CHECK: preceu.ph.qbr $17, $18   # encoding: [0x02,0x32,0xd1,0x3c]
  preceu.ph.qbra $19, $20      # CHECK: preceu.ph.qbra $19, $20  # encoding: [0x02,0x74,0xd3,0x3c]
  precrq.ph.w $8, $9, $10       # CHECK: precrq.ph.w $8, $9, $10       # encoding: [0x01,0x49,0x40,0xed]
  precrq.qb.ph $11, $12, $13    # CHECK: precrq.qb.ph $11, $12, $13    # encoding: [0x01,0xac,0x58,0xad]
  precrqu_s.qb.ph $14, $15, $16 # CHECK: precrqu_s.qb.ph $14, $15, $16 # encoding: [0x02,0x0f,0x71,0x6d]
  precrq_rs.ph.w $17, $18, $19  # CHECK: precrq_rs.ph.w $17, $18, $19  # encoding: [0x02,0x72,0x89,0x2d]
  shll.ph $3, $4, 5            # CHECK: shll.ph $3, $4, 5       # encoding: [0x00,0x64,0x53,0xb5]
  shll_s.ph $3, $4, 5          # CHECK: shll_s.ph $3, $4, 5     # encoding: [0x00,0x64,0x5b,0xb5]
  shll.qb $3, $4, 5            # CHECK: shll.qb $3, $4, 5       # encoding: [0x00,0x64,0xa8,0x7c]
  shllv.ph $3, $4, $5          # CHECK: shllv.ph $3, $4, $5     # encoding: [0x00,0x85,0x18,0x0e]
  shllv_s.ph $3, $4, $5        # CHECK: shllv_s.ph $3, $4, $5   # encoding: [0x00,0x85,0x1c,0x0e]
  shllv.qb $3, $4, $5          # CHECK: shllv.qb $3, $4, $5     # encoding: [0x00,0x85,0x1b,0x95]
  shllv_s.w $3, $4, $5         # CHECK: shllv_s.w $3, $4, $5    # encoding: [0x00,0x85,0x1b,0xd5]
  shll_s.w $3, $4, 5           # CHECK: shll_s.w $3, $4, 5      # encoding: [0x00,0x64,0x2b,0xf5]
  shra.ph $3, $4, 5            # CHECK: shra.ph $3, $4, 5       # encoding: [0x00,0x64,0x53,0x35]
  shra_r.ph $3, $4, 5          # CHECK: shra_r.ph $3, $4, 5     # encoding: [0x00,0x64,0x57,0x35]
  shrav.ph $3, $4, $5          # CHECK: shrav.ph $3, $4, $5     # encoding: [0x00,0x85,0x19,0x8d]
  shrav_r.ph $3, $4, $5        # CHECK: shrav_r.ph $3, $4, $5   # encoding: [0x00,0x85,0x1d,0x8d]
  shrav_r.w $3, $4, $5         # CHECK: shrav_r.w $3, $4, $5    # encoding: [0x00,0x85,0x1a,0xd5]
  shra_r.w $3, $4, 5           # CHECK: shra_r.w $3, $4, 5      # encoding: [0x00,0x64,0x2a,0xf5]
  shrl.qb $3, $4, 5            # CHECK: shrl.qb $3, $4, 5       # encoding: [0x00,0x64,0xb8,0x7c]
  shrlv.qb $3, $4, $5          # CHECK: shrlv.qb $3, $4, $5     # encoding: [0x00,0x85,0x1b,0x55]
  subq.ph $3, $4, $5           # CHECK: subq.ph $3, $4, $5      # encoding: [0x00,0xa4,0x1a,0x0d]
  subq_s.ph $3, $4, $5         # CHECK: subq_s.ph $3, $4, $5    # encoding: [0x00,0xa4,0x1e,0x0d]
  subq_s.w $3, $4, $5          # CHECK: subq_s.w $3, $4, $5     # encoding: [0x00,0xa4,0x1b,0x45]
  subu.qb $3, $4, $5           # CHECK: subu.qb $3, $4, $5      # encoding: [0x00,0xa4,0x1a,0xcd]
  subu_s.qb $3, $4, $5         # CHECK: subu_s.qb $3, $4, $5    # encoding: [0x00,0xa4,0x1e,0xcd]
  dpsq_s.w.ph $ac1, $4, $6     # CHECK: dpsq_s.w.ph $ac1, $4, $6   # encoding: [0x00,0xc4,0x46,0xbc]
  dpsq_sa.l.w $ac1, $4, $6     # CHECK: dpsq_sa.l.w $ac1, $4, $6   # encoding: [0x00,0xc4,0x56,0xbc]
  dpsu.h.qbl $ac1, $4, $6      # CHECK: dpsu.h.qbl $ac1, $4, $6    # encoding: [0x00,0xc4,0x64,0xbc]
  dpsu.h.qbr $ac1, $4, $6      # CHECK: dpsu.h.qbr $ac1, $4, $6    # encoding: [0x00,0xc4,0x74,0xbc]
  muleq_s.w.phl $1, $2, $3     # CHECK: muleq_s.w.phl $1, $2, $3   # encoding: [0x00,0x62,0x08,0x25]
  muleq_s.w.phr $1, $2, $3     # CHECK: muleq_s.w.phr $1, $2, $3   # encoding: [0x00,0x62,0x08,0x65]
  muleu_s.ph.qbl $1, $2, $3    # CHECK: muleu_s.ph.qbl $1, $2, $3  # encoding: [0x00,0x62,0x08,0x95]
  muleu_s.ph.qbr $1, $2, $3    # CHECK: muleu_s.ph.qbr $1, $2, $3  # encoding: [0x00,0x62,0x08,0xd5]
  mulq_rs.ph $1, $2, $3        # CHECK: mulq_rs.ph $1, $2, $3      # encoding: [0x00,0x62,0x09,0x15]
  lbux $1, $2($3)              # CHECK: lbux $1, $2($3)              # encoding: [0x00,0x43,0x0a,0x25]
  lhx $1, $2($3)               # CHECK: lhx $1, $2($3)               # encoding: [0x00,0x43,0x09,0x65]
  lwx $1, $2($3)               # CHECK: lwx $1, $2($3)               # encoding: [0x00,0x43,0x09,0xa5]
  maq_s.w.phl $ac1, $2, $3     # CHECK: maq_s.w.phl $ac1, $2, $3     # encoding: [0x00,0x62,0x5a,0x7c]
  maq_sa.w.phl $ac1, $2, $3    # CHECK: maq_sa.w.phl $ac1, $2, $3    # encoding: [0x00,0x62,0x7a,0x7c]
  maq_s.w.phr $ac1, $2, $3     # CHECK: maq_s.w.phr $ac1, $2, $3     # encoding: [0x00,0x62,0x4a,0x7c]
  maq_sa.w.phr $ac1, $2, $3    # CHECK: maq_sa.w.phr $ac1, $2, $3    # encoding: [0x00,0x62,0x6a,0x7c]
  mfhi $2, $ac1                # CHECK: mfhi $2, $ac1                # encoding: [0x00,0x02,0x40,0x7c]
  mflo $1, $ac1                # CHECK: mflo $1, $ac1                # encoding: [0x00,0x01,0x50,0x7c]
  mthi $1, $ac1                # CHECK: mthi $1, $ac1                # encoding: [0x00,0x01,0x60,0x7c]
  mtlo $1, $ac1                # CHECK: mtlo $1, $ac1                # encoding: [0x00,0x01,0x70,0x7c]
  raddu.w.qb $1, $2            # CHECK: raddu.w.qb $1, $2       # encoding: [0x00,0x22,0xf1,0x3c]
  rddsp $1, 2                  # CHECK: rddsp $1, 2             # encoding: [0x00,0x20,0x86,0x7c]
  repl.ph $1, 512              # CHECK: repl.ph $1, 512         # encoding: [0x02,0x00,0x08,0x3d]
  repl.qb $1, 128              # CHECK: repl.qb $1, 128         # encoding: [0x00,0x30,0x05,0xfc]
  replv.ph $1, $2              # CHECK: replv.ph $1, $2         # encoding: [0x00,0x22,0x03,0x3c]
  replv.qb $1, $2              # CHECK: replv.qb $1, $2         # encoding: [0x00,0x22,0x13,0x3c]
  mthlip $1, $ac2              # CHECK: mthlip $1, $ac2         # encoding: [0x00,0x01,0x82,0x7c]
