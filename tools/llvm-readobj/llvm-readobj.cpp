//===- llvm-readobj.cpp - Dump contents of an Object File -----------------===//
//
//                     The LLVM Compiler Infrastructure
//
// This file is distributed under the University of Illinois Open Source
// License. See LICENSE.TXT for details.
//
//===----------------------------------------------------------------------===//
//
// This is a tool similar to readelf, except it works on multiple object file
// formats. The main purpose of this tool is to provide detailed output suitable
// for FileCheck.
//
// Flags should be similar to readelf where supported, but the output format
// does not need to be identical. The point is to not make users learn yet
// another set of flags.
//
// Output should be specialized for each format where appropriate.
//
//===----------------------------------------------------------------------===//

#include "llvm-readobj.h"
#include "Error.h"
#include "ObjDumper.h"
#include "StreamWriter.h"
#include "llvm/Object/Archive.h"
#include "llvm/Object/COFFImportFile.h"
#include "llvm/Object/ELFObjectFile.h"
#include "llvm/Object/MachOUniversal.h"
#include "llvm/Object/ObjectFile.h"
#include "llvm/Support/Casting.h"
#include "llvm/Support/CommandLine.h"
#include "llvm/Support/DataTypes.h"
#include "llvm/Support/Debug.h"
#include "llvm/Support/FileSystem.h"
#include "llvm/Support/ManagedStatic.h"
#include "llvm/Support/PrettyStackTrace.h"
#include "llvm/Support/Signals.h"
#include "llvm/Support/TargetRegistry.h"
#include "llvm/Support/TargetSelect.h"
#include <string>
#include <system_error>

using namespace llvm;
using namespace llvm::object;

namespace opts {
  cl::list<std::string> InputFilenames(cl::Positional,
    cl::desc("<input object files>"),
    cl::ZeroOrMore);

  // -file-headers, -h
  cl::opt<bool> FileHeaders("file-headers",
    cl::desc("Display file headers "));
  cl::alias FileHeadersShort("h",
    cl::desc("Alias for --file-headers"),
    cl::aliasopt(FileHeaders));

  // -sections, -s
  cl::opt<bool> Sections("sections",
    cl::desc("Display all sections."));
  cl::alias SectionsShort("s",
    cl::desc("Alias for --sections"),
    cl::aliasopt(Sections));

  // -section-relocations, -sr
  cl::opt<bool> SectionRelocations("section-relocations",
    cl::desc("Display relocations for each section shown."));
  cl::alias SectionRelocationsShort("sr",
    cl::desc("Alias for --section-relocations"),
    cl::aliasopt(SectionRelocations));

  // -section-symbols, -st
  cl::opt<bool> SectionSymbols("section-symbols",
    cl::desc("Display symbols for each section shown."));
  cl::alias SectionSymbolsShort("st",
    cl::desc("Alias for --section-symbols"),
    cl::aliasopt(SectionSymbols));

  // -section-data, -sd
  cl::opt<bool> SectionData("section-data",
    cl::desc("Display section data for each section shown."));
  cl::alias SectionDataShort("sd",
    cl::desc("Alias for --section-data"),
    cl::aliasopt(SectionData));

  // -relocations, -r
  cl::opt<bool> Relocations("relocations",
    cl::desc("Display the relocation entries in the file"));
  cl::alias RelocationsShort("r",
    cl::desc("Alias for --relocations"),
    cl::aliasopt(Relocations));

  // -dyn-relocations
  cl::opt<bool> DynRelocs("dyn-relocations",
    cl::desc("Display the dynamic relocation entries in the file"));

  // -symbols, -t
  cl::opt<bool> Symbols("symbols",
    cl::desc("Display the symbol table"));
  cl::alias SymbolsShort("t",
    cl::desc("Alias for --symbols"),
    cl::aliasopt(Symbols));

  // -dyn-symbols, -dt
  cl::opt<bool> DynamicSymbols("dyn-symbols",
    cl::desc("Display the dynamic symbol table"));
  cl::alias DynamicSymbolsShort("dt",
    cl::desc("Alias for --dyn-symbols"),
    cl::aliasopt(DynamicSymbols));

  // -unwind, -u
  cl::opt<bool> UnwindInfo("unwind",
    cl::desc("Display unwind information"));
  cl::alias UnwindInfoShort("u",
    cl::desc("Alias for --unwind"),
    cl::aliasopt(UnwindInfo));

  // -dynamic-table
  cl::opt<bool> DynamicTable("dynamic-table",
    cl::desc("Display the ELF .dynamic section table"));

  // -needed-libs
  cl::opt<bool> NeededLibraries("needed-libs",
    cl::desc("Display the needed libraries"));

  // -program-headers
  cl::opt<bool> ProgramHeaders("program-headers",
    cl::desc("Display ELF program headers"));

  // -hash-table
  cl::opt<bool> HashTable("hash-table",
    cl::desc("Display ELF hash table"));

  // -gnu-hash-table
  cl::opt<bool> GnuHashTable("gnu-hash-table",
    cl::desc("Display ELF .gnu.hash section"));

  // -expand-relocs
  cl::opt<bool> ExpandRelocs("expand-relocs",
    cl::desc("Expand each shown relocation to multiple lines"));

  // -codeview
  cl::opt<bool> CodeView("codeview",
                         cl::desc("Display CodeView debug information"));

  // -codeview-subsection-bytes
  cl::opt<bool> CodeViewSubsectionBytes(
      "codeview-subsection-bytes",
      cl::desc("Dump raw contents of codeview debug sections and records"));

  // -arm-attributes, -a
  cl::opt<bool> ARMAttributes("arm-attributes",
                              cl::desc("Display the ARM attributes section"));
  cl::alias ARMAttributesShort("-a", cl::desc("Alias for --arm-attributes"),
                               cl::aliasopt(ARMAttributes));

  // -mips-plt-got
  cl::opt<bool>
  MipsPLTGOT("mips-plt-got",
             cl::desc("Display the MIPS GOT and PLT GOT sections"));

  // -mips-abi-flags
  cl::opt<bool> MipsABIFlags("mips-abi-flags",
                             cl::desc("Display the MIPS.abiflags section"));

  // -mips-reginfo
  cl::opt<bool> MipsReginfo("mips-reginfo",
                            cl::desc("Display the MIPS .reginfo section"));

  // -coff-imports
  cl::opt<bool>
  COFFImports("coff-imports", cl::desc("Display the PE/COFF import table"));

  // -coff-exports
  cl::opt<bool>
  COFFExports("coff-exports", cl::desc("Display the PE/COFF export table"));

  // -coff-directives
  cl::opt<bool>
  COFFDirectives("coff-directives",
                 cl::desc("Display the PE/COFF .drectve section"));

  // -coff-basereloc
  cl::opt<bool>
  COFFBaseRelocs("coff-basereloc",
                 cl::desc("Display the PE/COFF .reloc section"));

  // -macho-data-in-code
  cl::opt<bool>
  MachODataInCode("macho-data-in-code",
                  cl::desc("Display MachO Data in Code command"));

  // -macho-indirect-symbols
  cl::opt<bool>
  MachOIndirectSymbols("macho-indirect-symbols",
                  cl::desc("Display MachO indirect symbols"));

  // -macho-linker-options
  cl::opt<bool>
  MachOLinkerOptions("macho-linker-options",
                  cl::desc("Display MachO linker options"));

  // -macho-segment
  cl::opt<bool>
  MachOSegment("macho-segment",
                  cl::desc("Display MachO Segment command"));

  // -macho-version-min
  cl::opt<bool>
  MachOVersionMin("macho-version-min",
                  cl::desc("Display MachO version min command"));

  // -macho-dysymtab
  cl::opt<bool>
  MachODysymtab("macho-dysymtab",
                  cl::desc("Display MachO Dysymtab command"));

  // -stackmap
  cl::opt<bool>
  PrintStackMap("stackmap",
                cl::desc("Display contents of stackmap section"));

  // -version-info
  cl::opt<bool>
      VersionInfo("version-info",
                  cl::desc("Display ELF version sections (if present)"));
  cl::alias VersionInfoShort("V", cl::desc("Alias for -version-info"),
                             cl::aliasopt(VersionInfo));
} // namespace opts

namespace llvm {

LLVM_ATTRIBUTE_NORETURN void reportError(Twine Msg) {
  outs() << "\nError reading file: " << Msg << ".\n";
  outs().flush();
  exit(1);
}

void error(std::error_code EC) {
  if (!EC)
    return;

  reportError(EC.message());
}

bool relocAddressLess(RelocationRef a, RelocationRef b) {
  return a.getOffset() < b.getOffset();
}

} // namespace llvm

static void reportError(StringRef Input, std::error_code EC) {
  if (Input == "-")
    Input = "<stdin>";

  reportError(Twine(Input) + ": " + EC.message());
}

static void reportError(StringRef Input, StringRef Message) {
  if (Input == "-")
    Input = "<stdin>";

  reportError(Twine(Input) + ": " + Message);
}

static bool isMipsArch(unsigned Arch) {
  switch (Arch) {
  case llvm::Triple::mips:
  case llvm::Triple::mipsel:
  case llvm::Triple::mips64:
  case llvm::Triple::mips64el:
    return true;
  default:
    return false;
  }
}

/// @brief Creates an format-specific object file dumper.
static std::error_code createDumper(const ObjectFile *Obj, StreamWriter &Writer,
                                    std::unique_ptr<ObjDumper> &Result) {
  if (!Obj)
    return readobj_error::unsupported_file_format;

  if (Obj->isCOFF())
    return createCOFFDumper(Obj, Writer, Result);
  if (Obj->isELF())
    return createELFDumper(Obj, Writer, Result);
  if (Obj->isMachO())
    return createMachODumper(Obj, Writer, Result);

  return readobj_error::unsupported_obj_file_format;
}

/// @brief Dumps the specified object file.
static void dumpObject(const ObjectFile *Obj) {
  StreamWriter Writer(outs());
  std::unique_ptr<ObjDumper> Dumper;
  if (std::error_code EC = createDumper(Obj, Writer, Dumper))
    reportError(Obj->getFileName(), EC);

  outs() << '\n';
  outs() << "File: " << Obj->getFileName() << "\n";
  outs() << "Format: " << Obj->getFileFormatName() << "\n";
  outs() << "Arch: "
         << Triple::getArchTypeName((llvm::Triple::ArchType)Obj->getArch())
         << "\n";
  outs() << "AddressSize: " << (8*Obj->getBytesInAddress()) << "bit\n";
  Dumper->printLoadName();

  if (opts::FileHeaders)
    Dumper->printFileHeaders();
  if (opts::Sections)
    Dumper->printSections();
  if (opts::Relocations)
    Dumper->printRelocations();
  if (opts::DynRelocs)
    Dumper->printDynamicRelocations();
  if (opts::Symbols)
    Dumper->printSymbols();
  if (opts::DynamicSymbols)
    Dumper->printDynamicSymbols();
  if (opts::UnwindInfo)
    Dumper->printUnwindInfo();
  if (opts::DynamicTable)
    Dumper->printDynamicTable();
  if (opts::NeededLibraries)
    Dumper->printNeededLibraries();
  if (opts::ProgramHeaders)
    Dumper->printProgramHeaders();
  if (opts::HashTable)
    Dumper->printHashTable();
  if (opts::GnuHashTable)
    Dumper->printGnuHashTable();
  if (opts::VersionInfo)
    Dumper->printVersionInfo();
  if (Obj->getArch() == llvm::Triple::arm && Obj->isELF())
    if (opts::ARMAttributes)
      Dumper->printAttributes();
  if (isMipsArch(Obj->getArch()) && Obj->isELF()) {
    if (opts::MipsPLTGOT)
      Dumper->printMipsPLTGOT();
    if (opts::MipsABIFlags)
      Dumper->printMipsABIFlags();
    if (opts::MipsReginfo)
      Dumper->printMipsReginfo();
  }
  if (Obj->isCOFF()) {
    if (opts::COFFImports)
      Dumper->printCOFFImports();
    if (opts::COFFExports)
      Dumper->printCOFFExports();
    if (opts::COFFDirectives)
      Dumper->printCOFFDirectives();
    if (opts::COFFBaseRelocs)
      Dumper->printCOFFBaseReloc();
  }
  if (Obj->isMachO()) {
    if (opts::MachODataInCode)
      Dumper->printMachODataInCode();
    if (opts::MachOIndirectSymbols)
      Dumper->printMachOIndirectSymbols();
    if (opts::MachOLinkerOptions)
      Dumper->printMachOLinkerOptions();
    if (opts::MachOSegment)
      Dumper->printMachOSegment();
    if (opts::MachOVersionMin)
      Dumper->printMachOVersionMin();
    if (opts::MachODysymtab)
      Dumper->printMachODysymtab();
  }
  if (opts::PrintStackMap)
    Dumper->printStackMap();
}

/// @brief Dumps each object file in \a Arc;
static void dumpArchive(const Archive *Arc) {
  for (auto &ErrorOrChild : Arc->children()) {
    if (std::error_code EC = ErrorOrChild.getError())
      reportError(Arc->getFileName(), EC.message());
    const auto &Child = *ErrorOrChild;
    ErrorOr<std::unique_ptr<Binary>> ChildOrErr = Child.getAsBinary();
    if (std::error_code EC = ChildOrErr.getError()) {
      // Ignore non-object files.
      if (EC != object_error::invalid_file_type)
        reportError(Arc->getFileName(), EC.message());
      continue;
    }

    if (ObjectFile *Obj = dyn_cast<ObjectFile>(&*ChildOrErr.get()))
      dumpObject(Obj);
    else
      reportError(Arc->getFileName(), readobj_error::unrecognized_file_format);
  }
}

/// @brief Dumps each object file in \a MachO Universal Binary;
static void dumpMachOUniversalBinary(const MachOUniversalBinary *UBinary) {
  for (const MachOUniversalBinary::ObjectForArch &Obj : UBinary->objects()) {
    ErrorOr<std::unique_ptr<MachOObjectFile>> ObjOrErr = Obj.getAsObjectFile();
    if (ObjOrErr)
      dumpObject(&*ObjOrErr.get());
    else if (ErrorOr<std::unique_ptr<Archive>> AOrErr = Obj.getAsArchive())
      dumpArchive(&*AOrErr.get());
    else
      reportError(UBinary->getFileName(), ObjOrErr.getError().message());
  }
}

/// @brief Opens \a File and dumps it.
static void dumpInput(StringRef File) {

  // Attempt to open the binary.
  ErrorOr<OwningBinary<Binary>> BinaryOrErr = createBinary(File);
  if (std::error_code EC = BinaryOrErr.getError())
    reportError(File, EC);
  Binary &Binary = *BinaryOrErr.get().getBinary();

  if (Archive *Arc = dyn_cast<Archive>(&Binary))
    dumpArchive(Arc);
  else if (MachOUniversalBinary *UBinary =
               dyn_cast<MachOUniversalBinary>(&Binary))
    dumpMachOUniversalBinary(UBinary);
  else if (ObjectFile *Obj = dyn_cast<ObjectFile>(&Binary))
    dumpObject(Obj);
  else if (COFFImportFile *Import = dyn_cast<COFFImportFile>(&Binary))
    dumpCOFFImportFile(Import);
  else
    reportError(File, readobj_error::unrecognized_file_format);
}

int main(int argc, const char *argv[]) {
  sys::PrintStackTraceOnErrorSignal();
  PrettyStackTraceProgram X(argc, argv);
  llvm_shutdown_obj Y;

  // Register the target printer for --version.
  cl::AddExtraVersionPrinter(TargetRegistry::printRegisteredTargetsForVersion);

  cl::ParseCommandLineOptions(argc, argv, "LLVM Object Reader\n");

  // Default to stdin if no filename is specified.
  if (opts::InputFilenames.size() == 0)
    opts::InputFilenames.push_back("-");

  std::for_each(opts::InputFilenames.begin(), opts::InputFilenames.end(),
                dumpInput);

  return 0;
}
