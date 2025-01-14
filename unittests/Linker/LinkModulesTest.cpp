//===- llvm/unittest/Linker/LinkModulesTest.cpp - IRBuilder tests ---------===//
//
//                     The LLVM Compiler Infrastructure
//
// This file is distributed under the University of Illinois Open Source
// License. See LICENSE.TXT for details.
//
//===----------------------------------------------------------------------===//

#include "llvm/ADT/STLExtras.h"
#include "llvm/AsmParser/Parser.h"
#include "llvm/IR/BasicBlock.h"
#include "llvm/IR/DataLayout.h"
#include "llvm/IR/Function.h"
#include "llvm/IR/IRBuilder.h"
#include "llvm/IR/Module.h"
#include "llvm/Linker/Linker.h"
#include "llvm/Support/SourceMgr.h"
#include "llvm-c/Linker.h"
#include "gtest/gtest.h"

using namespace llvm;

namespace {

class LinkModuleTest : public testing::Test {
protected:
  void SetUp() override {
    M.reset(new Module("MyModule", Ctx));
    FunctionType *FTy = FunctionType::get(
        Type::getInt8PtrTy(Ctx), Type::getInt32Ty(Ctx), false /*=isVarArg*/);
    F = Function::Create(FTy, Function::ExternalLinkage, "ba_func", M.get());
    F->setCallingConv(CallingConv::C);

    EntryBB = BasicBlock::Create(Ctx, "entry", F);
    SwitchCase1BB = BasicBlock::Create(Ctx, "switch.case.1", F);
    SwitchCase2BB = BasicBlock::Create(Ctx, "switch.case.2", F);
    ExitBB = BasicBlock::Create(Ctx, "exit", F);

    AT = ArrayType::get(Type::getInt8PtrTy(Ctx), 3);

    GV = new GlobalVariable(*M.get(), AT, false /*=isConstant*/,
                            GlobalValue::InternalLinkage, nullptr,"switch.bas");

    // Global Initializer
    std::vector<Constant *> Init;
    Constant *SwitchCase1BA = BlockAddress::get(SwitchCase1BB);
    Init.push_back(SwitchCase1BA);

    Constant *SwitchCase2BA = BlockAddress::get(SwitchCase2BB);
    Init.push_back(SwitchCase2BA);

    ConstantInt *One = ConstantInt::get(Type::getInt32Ty(Ctx), 1);
    Constant *OnePtr = ConstantExpr::getCast(Instruction::IntToPtr, One,
                                             Type::getInt8PtrTy(Ctx));
    Init.push_back(OnePtr);

    GV->setInitializer(ConstantArray::get(AT, Init));
  }

  void TearDown() override { M.reset(); }

  LLVMContext Ctx;
  std::unique_ptr<Module> M;
  Function *F;
  ArrayType *AT;
  GlobalVariable *GV;
  BasicBlock *EntryBB;
  BasicBlock *SwitchCase1BB;
  BasicBlock *SwitchCase2BB;
  BasicBlock *ExitBB;
};

static void expectNoDiags(const DiagnosticInfo &DI) { EXPECT_TRUE(false); }

TEST_F(LinkModuleTest, BlockAddress) {
  IRBuilder<> Builder(EntryBB);

  std::vector<Value *> GEPIndices;
  GEPIndices.push_back(ConstantInt::get(Type::getInt32Ty(Ctx), 0));
  GEPIndices.push_back(&*F->arg_begin());

  Value *GEP = Builder.CreateGEP(AT, GV, GEPIndices, "switch.gep");
  Value *Load = Builder.CreateLoad(GEP, "switch.load");

  Builder.CreateRet(Load);

  Builder.SetInsertPoint(SwitchCase1BB);
  Builder.CreateBr(ExitBB);

  Builder.SetInsertPoint(SwitchCase2BB);
  Builder.CreateBr(ExitBB);

  Builder.SetInsertPoint(ExitBB);
  Builder.CreateRet(ConstantPointerNull::get(Type::getInt8PtrTy(Ctx)));

  Module *LinkedModule = new Module("MyModuleLinked", Ctx);
  Linker::linkModules(*LinkedModule, *M, expectNoDiags);

  // Delete the original module.
  M.reset();

  // Check that the global "@switch.bas" is well-formed.
  const GlobalVariable *LinkedGV = LinkedModule->getNamedGlobal("switch.bas");
  const Constant *Init = LinkedGV->getInitializer();

  // @switch.bas = internal global [3 x i8*]
  //   [i8* blockaddress(@ba_func, %switch.case.1),
  //    i8* blockaddress(@ba_func, %switch.case.2),
  //    i8* inttoptr (i32 1 to i8*)]

  ArrayType *AT = ArrayType::get(Type::getInt8PtrTy(Ctx), 3);
  EXPECT_EQ(AT, Init->getType());

  Value *Elem = Init->getOperand(0);
  ASSERT_TRUE(isa<BlockAddress>(Elem));
  EXPECT_EQ(cast<BlockAddress>(Elem)->getFunction(),
            LinkedModule->getFunction("ba_func"));
  EXPECT_EQ(cast<BlockAddress>(Elem)->getBasicBlock()->getParent(),
            LinkedModule->getFunction("ba_func"));

  Elem = Init->getOperand(1);
  ASSERT_TRUE(isa<BlockAddress>(Elem));
  EXPECT_EQ(cast<BlockAddress>(Elem)->getFunction(),
            LinkedModule->getFunction("ba_func"));
  EXPECT_EQ(cast<BlockAddress>(Elem)->getBasicBlock()->getParent(),
            LinkedModule->getFunction("ba_func"));

  delete LinkedModule;
}

static Module *getExternal(LLVMContext &Ctx, StringRef FuncName) {
  // Create a module with an empty externally-linked function
  Module *M = new Module("ExternalModule", Ctx);
  FunctionType *FTy = FunctionType::get(
      Type::getVoidTy(Ctx), Type::getInt8PtrTy(Ctx), false /*=isVarArgs*/);

  Function *F =
      Function::Create(FTy, Function::ExternalLinkage, FuncName, M);
  F->setCallingConv(CallingConv::C);

  BasicBlock *BB = BasicBlock::Create(Ctx, "", F);
  IRBuilder<> Builder(BB);
  Builder.CreateRetVoid();
  return M;
}

static Module *getInternal(LLVMContext &Ctx) {
  Module *InternalM = new Module("InternalModule", Ctx);
  FunctionType *FTy = FunctionType::get(
      Type::getVoidTy(Ctx), Type::getInt8PtrTy(Ctx), false /*=isVarArgs*/);

  Function *F =
      Function::Create(FTy, Function::InternalLinkage, "bar", InternalM);
  F->setCallingConv(CallingConv::C);

  BasicBlock *BB = BasicBlock::Create(Ctx, "", F);
  IRBuilder<> Builder(BB);
  Builder.CreateRetVoid();

  StructType *STy = StructType::create(Ctx, PointerType::get(FTy, 0));

  GlobalVariable *GV =
      new GlobalVariable(*InternalM, STy, false /*=isConstant*/,
                         GlobalValue::InternalLinkage, nullptr, "g");

  GV->setInitializer(ConstantStruct::get(STy, F));
  return InternalM;
}

TEST_F(LinkModuleTest, EmptyModule) {
  std::unique_ptr<Module> InternalM(getInternal(Ctx));
  std::unique_ptr<Module> EmptyM(new Module("EmptyModule1", Ctx));
  Linker::linkModules(*EmptyM, *InternalM, expectNoDiags);
}

TEST_F(LinkModuleTest, EmptyModule2) {
  std::unique_ptr<Module> InternalM(getInternal(Ctx));
  std::unique_ptr<Module> EmptyM(new Module("EmptyModule1", Ctx));
  Linker::linkModules(*InternalM, *EmptyM, expectNoDiags);
}

TEST_F(LinkModuleTest, TypeMerge) {
  LLVMContext C;
  SMDiagnostic Err;

  const char *M1Str = "%t = type {i32}\n"
                      "@t1 = weak global %t zeroinitializer\n";
  std::unique_ptr<Module> M1 = parseAssemblyString(M1Str, Err, C);

  const char *M2Str = "%t = type {i32}\n"
                      "@t2 = weak global %t zeroinitializer\n";
  std::unique_ptr<Module> M2 = parseAssemblyString(M2Str, Err, C);

  Linker::linkModules(*M1, *M2, [](const llvm::DiagnosticInfo &) {});

  EXPECT_EQ(M1->getNamedGlobal("t1")->getType(),
            M1->getNamedGlobal("t2")->getType());
}

TEST_F(LinkModuleTest, CAPISuccess) {
  std::unique_ptr<Module> DestM(getExternal(Ctx, "foo"));
  std::unique_ptr<Module> SourceM(getExternal(Ctx, "bar"));
  char *errout = nullptr;
  LLVMBool result = LLVMLinkModules(wrap(DestM.get()), wrap(SourceM.get()),
                                    LLVMLinkerDestroySource, &errout);
  EXPECT_EQ(0, result);
  EXPECT_EQ(nullptr, errout);
  // "bar" is present in destination module
  EXPECT_NE(nullptr, DestM->getFunction("bar"));
}

TEST_F(LinkModuleTest, CAPIFailure) {
  // Symbol clash between two modules
  std::unique_ptr<Module> DestM(getExternal(Ctx, "foo"));
  std::unique_ptr<Module> SourceM(getExternal(Ctx, "foo"));
  char *errout = nullptr;
  LLVMBool result = LLVMLinkModules(wrap(DestM.get()), wrap(SourceM.get()),
                                    LLVMLinkerDestroySource, &errout);
  EXPECT_EQ(1, result);
  EXPECT_STREQ("Linking globals named 'foo': symbol multiply defined!", errout);
  LLVMDisposeMessage(errout);
}

TEST_F(LinkModuleTest, MoveDistinctMDs) {
  LLVMContext C;
  SMDiagnostic Err;

  const char *SrcStr = "define void @foo() !attach !0 {\n"
                       "entry:\n"
                       "  call void @llvm.md(metadata !1)\n"
                       "  ret void, !attach !2\n"
                       "}\n"
                       "declare void @llvm.md(metadata)\n"
                       "!named = !{!3, !4}\n"
                       "!0 = distinct !{}\n"
                       "!1 = distinct !{}\n"
                       "!2 = distinct !{}\n"
                       "!3 = distinct !{}\n"
                       "!4 = !{!3}\n";

  std::unique_ptr<Module> Src = parseAssemblyString(SrcStr, Err, C);
  assert(Src);
  ASSERT_TRUE(Src.get());

  // Get the addresses of the Metadata before merging.
  Function *F = &*Src->begin();
  ASSERT_EQ("foo", F->getName());
  BasicBlock *BB = &F->getEntryBlock();
  auto *CI = cast<CallInst>(&BB->front());
  auto *RI = cast<ReturnInst>(BB->getTerminator());
  NamedMDNode *NMD = &*Src->named_metadata_begin();

  MDNode *M0 = F->getMetadata("attach");
  MDNode *M1 =
      cast<MDNode>(cast<MetadataAsValue>(CI->getArgOperand(0))->getMetadata());
  MDNode *M2 = RI->getMetadata("attach");
  MDNode *M3 = NMD->getOperand(0);
  MDNode *M4 = NMD->getOperand(1);

  // Confirm a few things about the IR.
  EXPECT_TRUE(M0->isDistinct());
  EXPECT_TRUE(M1->isDistinct());
  EXPECT_TRUE(M2->isDistinct());
  EXPECT_TRUE(M3->isDistinct());
  EXPECT_TRUE(M4->isUniqued());
  EXPECT_EQ(M3, M4->getOperand(0));

  // Link into destination module.
  auto Dst = llvm::make_unique<Module>("Linked", C);
  ASSERT_TRUE(Dst.get());
  Linker::linkModules(*Dst, *Src, [](const llvm::DiagnosticInfo &) {});

  // Check that distinct metadata was moved, not cloned.  Even !4, the uniqued
  // node, should effectively be moved, since its only operand hasn't changed.
  F = &*Dst->begin();
  BB = &F->getEntryBlock();
  CI = cast<CallInst>(&BB->front());
  RI = cast<ReturnInst>(BB->getTerminator());
  NMD = &*Dst->named_metadata_begin();

  EXPECT_EQ(M0, F->getMetadata("attach"));
  EXPECT_EQ(M1, cast<MetadataAsValue>(CI->getArgOperand(0))->getMetadata());
  EXPECT_EQ(M2, RI->getMetadata("attach"));
  EXPECT_EQ(M3, NMD->getOperand(0));
  EXPECT_EQ(M4, NMD->getOperand(1));

  // Confirm a few things about the IR.  This shouldn't have changed.
  EXPECT_TRUE(M0->isDistinct());
  EXPECT_TRUE(M1->isDistinct());
  EXPECT_TRUE(M2->isDistinct());
  EXPECT_TRUE(M3->isDistinct());
  EXPECT_TRUE(M4->isUniqued());
  EXPECT_EQ(M3, M4->getOperand(0));
}

} // end anonymous namespace
