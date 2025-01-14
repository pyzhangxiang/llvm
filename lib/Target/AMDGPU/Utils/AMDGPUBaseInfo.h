//===-- AMDGPUBaseInfo.h - Top level definitions for AMDGPU -----*- C++ -*-===//
//
//                     The LLVM Compiler Infrastructure
//
// This file is distributed under the University of Illinois Open Source
// License. See LICENSE.TXT for details.
//
//===----------------------------------------------------------------------===//

#ifndef LLVM_LIB_TARGET_AMDGPU_UTILS_AMDGPUBASEINFO_H
#define LLVM_LIB_TARGET_AMDGPU_UTILS_AMDGPUBASEINFO_H

#include "AMDKernelCodeT.h"

namespace llvm {

class FeatureBitset;
class GlobalValue;
class MCContext;
class MCSection;

namespace AMDGPU {

struct IsaVersion {
  unsigned Major;
  unsigned Minor;
  unsigned Stepping;
};

IsaVersion getIsaVersion(const FeatureBitset &Features);
void initDefaultAMDKernelCodeT(amd_kernel_code_t &Header,
                               const FeatureBitset &Features);
MCSection *getHSATextSection(MCContext &Ctx);

MCSection *getHSADataGlobalAgentSection(MCContext &Ctx);

MCSection *getHSADataGlobalProgramSection(MCContext &Ctx);

MCSection *getHSARodataReadonlyAgentSection(MCContext &Ctx);

bool isGroupSegment(const GlobalValue *GV);
bool isGlobalSegment(const GlobalValue *GV);
bool isReadOnlySegment(const GlobalValue *GV);

} // end namespace AMDGPU
} // end namespace llvm

#endif
