; RUN: opt -mtriple=x86_64-pc-windows-msvc -S -winehprepare  < %s | FileCheck %s

declare i32 @__CxxFrameHandler3(...)
declare i32 @__C_specific_handler(...)

declare void @f()
declare i32 @g()
declare void @h(i32)
declare i1 @b()


define void @test1() personality i32 (...)* @__CxxFrameHandler3 {
entry:
  ; %x def colors: {entry} subset of use colors; must spill
  %x = call i32 @g()
  invoke void @f()
    to label %noreturn unwind label %catch.switch
catch.switch:
  %cs = catchswitch within none [label %catch] unwind to caller
catch:
  catchpad within %cs []
  br label %noreturn
noreturn:
  ; %x use colors: {entry, cleanup}
  call void @h(i32 %x)
  unreachable
}
; Need two copies of the call to @h, one under entry and one under catch.
; Currently we generate a load for each, though we shouldn't need one
; for the use in entry's copy.
; CHECK-LABEL: define void @test1(
; CHECK: entry:
; CHECK:   %x = call i32 @g()
; CHECK:   invoke void @f()
; CHECK:     to label %[[EntryCopy:[^ ]+]] unwind label %catch
; CHECK: catch.switch:
; CHECK:   %cs = catchswitch within none [label %catch] unwind to caller
; CHECK: catch:
; CHECK:   catchpad within %cs []
; CHECK-NEXT: call void @h(i32 %x)
; CHECK: [[EntryCopy]]:
; CHECK:   call void @h(i32 %x)


define void @test2() personality i32 (...)* @__CxxFrameHandler3 {
entry:
  invoke void @f()
    to label %exit unwind label %cleanup
cleanup:
  cleanuppad within none []
  br label %exit
exit:
  call void @f()
  ret void
}
; Need two copies of %exit's call to @f -- the subsequent ret is only
; valid when coming from %entry, but on the path from %cleanup, this
; might be a valid call to @f which might dynamically not return.
; CHECK-LABEL: define void @test2(
; CHECK: entry:
; CHECK:   invoke void @f()
; CHECK:     to label %[[exit:[^ ]+]] unwind label %cleanup
; CHECK: cleanup:
; CHECK:   cleanuppad within none []
; CHECK:   call void @f()
; CHECK-NEXT: unreachable
; CHECK: [[exit]]:
; CHECK:   call void @f()
; CHECK-NEXT: ret void


define void @test3() personality i32 (...)* @__CxxFrameHandler3 {
entry:
  invoke void @f()
    to label %invoke.cont unwind label %catch.switch
invoke.cont:
  invoke void @f()
    to label %exit unwind label %cleanup
catch.switch:
  %cs = catchswitch within none [label %catch] unwind to caller
catch:
  catchpad within %cs []
  br label %shared
cleanup:
  cleanuppad within none []
  br label %shared
shared:
  call void @f()
  br label %exit
exit:
  ret void
}
; Need two copies of %shared's call to @f (similar to @test2 but
; the two regions here are siblings, not parent-child).
; CHECK-LABEL: define void @test3(
; CHECK:   invoke void @f()
; CHECK:   invoke void @f()
; CHECK:     to label %[[exit:[^ ]+]] unwind
; CHECK: catch:
; CHECK:   catchpad within %cs []
; CHECK-NEXT: call void @f()
; CHECK-NEXT: unreachable
; CHECK: cleanup:
; CHECK:   cleanuppad within none []
; CHECK:   call void @f()
; CHECK-NEXT: unreachable
; CHECK: [[exit]]:
; CHECK:   ret void


define void @test4() personality i32 (...)* @__CxxFrameHandler3 {
entry:
  invoke void @f()
    to label %shared unwind label %catch.switch
catch.switch:
  %cs = catchswitch within none [label %catch] unwind to caller
catch:
  catchpad within %cs []
  br label %shared
shared:
  %x = call i32 @g()
  %i = call i32 @g()
  %zero.trip = icmp eq i32 %i, 0
  br i1 %zero.trip, label %exit, label %loop
loop:
  %i.loop = phi i32 [ %i, %shared ], [ %i.dec, %loop.tail ]
  %b = call i1 @b()
  br i1 %b, label %left, label %right
left:
  %y = call i32 @g()
  br label %loop.tail
right:
  call void @h(i32 %x)
  br label %loop.tail
loop.tail:
  %i.dec = sub i32 %i.loop, 1
  %done = icmp eq i32 %i.dec, 0
  br i1 %done, label %exit, label %loop
exit:
  call void @h(i32 %x)
  unreachable
}
; Make sure we can clone regions that have internal control
; flow and SSA values.  Here we need two copies of everything
; from %shared to %exit.
; CHECK-LABEL: define void @test4(
; CHECK:  entry:
; CHECK:    to label %[[shared_E:[^ ]+]] unwind label %catch.switch
; CHECK:  catch:
; CHECK:    catchpad within %cs []
; CHECK:    [[x_C:%[^ ]+]] = call i32 @g()
; CHECK:    [[i_C:%[^ ]+]] = call i32 @g()
; CHECK:    [[zt_C:%[^ ]+]] = icmp eq i32 [[i_C]], 0
; CHECK:    br i1 [[zt_C]], label %[[exit_C:[^ ]+]], label %[[loop_C:[^ ]+]]
; CHECK:  [[shared_E]]:
; CHECK:    [[x_E:%[^ ]+]] = call i32 @g()
; CHECK:    [[i_E:%[^ ]+]] = call i32 @g()
; CHECK:    [[zt_E:%[^ ]+]] = icmp eq i32 [[i_E]], 0
; CHECK:    br i1 [[zt_E]], label %[[exit_E:[^ ]+]], label %[[loop_E:[^ ]+]]
; CHECK:  [[loop_C]]:
; CHECK:    [[iloop_C:%[^ ]+]] = phi i32 [ [[i_C]], %catch ], [ [[idec_C:%[^ ]+]], %[[looptail_C:[^ ]+]] ]
; CHECK:    [[b_C:%[^ ]+]] = call i1 @b()
; CHECK:    br i1 [[b_C]], label %[[left_C:[^ ]+]], label %[[right_C:[^ ]+]]
; CHECK:  [[loop_E]]:
; CHECK:    [[iloop_E:%[^ ]+]] = phi i32 [ [[i_E]], %[[shared_E]] ], [ [[idec_E:%[^ ]+]], %[[looptail_E:[^ ]+]] ]
; CHECK:    [[b_E:%[^ ]+]] = call i1 @b()
; CHECK:    br i1 [[b_E]], label %[[left_E:[^ ]+]], label %[[right_E:[^ ]+]]
; CHECK:  [[left_C]]:
; CHECK:    [[y_C:%[^ ]+]] = call i32 @g()
; CHECK:    br label %[[looptail_C]]
; CHECK:  [[left_E]]:
; CHECK:    [[y_E:%[^ ]+]] = call i32 @g()
; CHECK:    br label %[[looptail_E]]
; CHECK:  [[right_C]]:
; CHECK:    call void @h(i32 [[x_C]])
; CHECK:    br label %[[looptail_C]]
; CHECK:  [[right_E]]:
; CHECK:    call void @h(i32 [[x_E]])
; CHECK:    br label %[[looptail_E]]
; CHECK:  [[looptail_C]]:
; CHECK:    [[idec_C]] = sub i32 [[iloop_C]], 1
; CHECK:    [[done_C:%[^ ]+]] = icmp eq i32 [[idec_C]], 0
; CHECK:    br i1 [[done_C]], label %[[exit_C]], label %[[loop_C]]
; CHECK:  [[looptail_E]]:
; CHECK:    [[idec_E]] = sub i32 [[iloop_E]], 1
; CHECK:    [[done_E:%[^ ]+]] = icmp eq i32 [[idec_E]], 0
; CHECK:    br i1 [[done_E]], label %[[exit_E]], label %[[loop_E]]
; CHECK:  [[exit_C]]:
; CHECK:    call void @h(i32 [[x_C]])
; CHECK:    unreachable
; CHECK:  [[exit_E]]:
; CHECK:    call void @h(i32 [[x_E]])
; CHECK:    unreachable


define void @test5() personality i32 (...)* @__C_specific_handler {
entry:
  invoke void @f()
    to label %exit unwind label %outer
outer:
  %o = cleanuppad within none []
  %x = call i32 @g()
  invoke void @f()
    to label %outer.ret unwind label %catch.switch
catch.switch:
  %cs = catchswitch within %o [label %inner] unwind to caller
inner:
  %i = catchpad within %cs []
  catchret from %i to label %outer.post-inner
outer.post-inner:
  call void @h(i32 %x)
  br label %outer.ret
outer.ret:
  cleanupret from %o unwind to caller
exit:
  ret void
}
; Simple nested case (catch-inside-cleanup).  Nothing needs
; to be cloned.  The def and use of %x are both in %outer
; and so don't need to be spilled.
; CHECK-LABEL: define void @test5(
; CHECK:      outer:
; CHECK:        %x = call i32 @g()
; CHECK-NEXT:   invoke void @f()
; CHECK-NEXT:     to label %outer.ret unwind label %catch.switch
; CHECK:      inner:
; CHECK-NEXT:   %i = catchpad within %cs []
; CHECK-NEXT:   catchret from %i to label %outer.post-inner
; CHECK:      outer.post-inner:
; CHECK-NEXT:   call void @h(i32 %x)
; CHECK-NEXT:   br label %outer.ret


define void @test6() personality i32 (...)* @__C_specific_handler {
entry:
  invoke void @f()
    to label %invoke.cont unwind label %left
invoke.cont:
  invoke void @f()
    to label %exit unwind label %right
left:
  cleanuppad within none []
  br label %shared
right:
  %cs = catchswitch within none [label %right.catch] unwind to caller
right.catch:
  catchpad within %cs []
  br label %shared
shared:
  %x = call i32 @g()
  invoke void @f()
    to label %shared.cont unwind label %inner
shared.cont:
  unreachable
inner:
  %i = cleanuppad within none []
  call void @h(i32 %x)
  cleanupret from %i unwind to caller
exit:
  ret void
}
; CHECK-LABEL: define void @test6(
; CHECK:     left:
; CHECK:       %x.for.left = call i32 @g()
; CHECK:       invoke void @f()
; CHECK:           to label %shared.cont.for.left unwind label %inner
; CHECK:     right.catch:
; CHECK:       catchpad
; CHECK:       %x = call i32 @g()
; CHECK:           to label %shared.cont unwind label %inner
; CHECK:     shared.cont:
; CHECK:       unreachable
; CHECK:     shared.cont.for.left:
; CHECK:       unreachable
; CHECK:     inner:
; CHECK:       %i = cleanuppad within none []
; CHECK:       call void @h(i32 %x1.wineh.reload)
; CHECK:       cleanupret from %i unwind to caller


define void @test9() personality i32 (...)* @__C_specific_handler {
entry:
  invoke void @f()
    to label %invoke.cont unwind label %left
invoke.cont:
  invoke void @f()
    to label %unreachable unwind label %right
left:
  cleanuppad within none []
  call void @h(i32 1)
  invoke void @f()
    to label %unreachable unwind label %right
right:
  cleanuppad within none []
  call void @h(i32 2)
  invoke void @f()
    to label %unreachable unwind label %left
unreachable:
  unreachable
}
; This is an irreducible loop with two funclets that enter each other.
; CHECK-LABEL: define void @test9(
; CHECK:     entry:
; CHECK:               to label %invoke.cont unwind label %[[LEFT:.+]]
; CHECK:     invoke.cont:
; CHECK:               to label %[[UNREACHABLE_ENTRY:.+]] unwind label %[[RIGHT:.+]]
; CHECK:     [[LEFT]]:
; CHECK:       call void @h(i32 1)
; CHECK:       invoke void @f()
; CHECK:               to label %[[UNREACHABLE_LEFT:.+]] unwind label %[[RIGHT]]
; CHECK:     [[RIGHT]]:
; CHECK:       call void @h(i32 2)
; CHECK:       invoke void @f()
; CHECK:               to label %[[UNREACHABLE_RIGHT:.+]] unwind label %[[LEFT]]
; CHECK:     [[UNREACHABLE_RIGHT]]:
; CHECK:       unreachable
; CHECK:     [[UNREACHABLE_LEFT]]:
; CHECK:       unreachable
; CHECK:     [[UNREACHABLE_ENTRY]]:
; CHECK:       unreachable


define void @test10() personality i32 (...)* @__CxxFrameHandler3 {
entry:
  invoke void @f()
    to label %unreachable unwind label %inner
inner:
  %cleanup = cleanuppad within none []
  ; make sure we don't overlook this cleanupret and try to process
  ; successor %outer as a child of inner.
  cleanupret from %cleanup unwind label %outer
outer:
  %cs = catchswitch within none [label %catch.body] unwind to caller

catch.body:
  %catch = catchpad within %cs []
  catchret from %catch to label %exit
exit:
  ret void
unreachable:
  unreachable
}
; CHECK-LABEL: define void @test10(
; CHECK-NEXT: entry:
; CHECK-NEXT:   invoke
; CHECK-NEXT:     to label %unreachable unwind label %inner
; CHECK:      inner:
; CHECK-NEXT:   %cleanup = cleanuppad within none []
; CHECK-NEXT:   cleanupret from %cleanup unwind label %outer
; CHECK:      outer:
; CHECK-NEXT:   %cs = catchswitch within none [label %catch.body] unwind to caller
; CHECK:      catch.body:
; CHECK-NEXT:   %catch = catchpad within %cs []
; CHECK-NEXT:   catchret from %catch to label %exit
; CHECK:      exit:
; CHECK-NEXT:   ret void

define void @test11() personality i32 (...)* @__C_specific_handler {
entry:
  invoke void @f()
    to label %exit unwind label %cleanup.outer
cleanup.outer:
  %outer = cleanuppad within none []
  invoke void @f()
    to label %outer.cont unwind label %cleanup.inner
outer.cont:
  br label %merge
cleanup.inner:
  %inner = cleanuppad within %outer []
  br label %merge
merge:
  call void @f()
  unreachable
exit:
  ret void
}
; merge.end will get cloned for outer and inner, but is implausible
; from inner, so the call @f() in inner's copy of merge should be
; rewritten to call @f()
; CHECK-LABEL: define void @test11()
; CHECK:      %inner = cleanuppad within %outer []
; CHECK-NEXT: call void @f()
; CHECK-NEXT: unreachable

define void @test12() personality i32 (...)* @__CxxFrameHandler3 !dbg !5 {
entry:
  invoke void @f()
    to label %cont unwind label %left, !dbg !8
cont:
  invoke void @f()
    to label %exit unwind label %right
left:
  cleanuppad within none []
  br label %join
right:
  cleanuppad within none []
  br label %join
join:
  ; This call will get cloned; make sure we can handle cloning
  ; instructions with debug metadata attached.
  call void @f(), !dbg !9
  unreachable
exit:
  ret void
}

; CHECK-LABEL: define void @test13()
; CHECK: ret void
define void @test13() personality i32 (...)* @__CxxFrameHandler3 {
entry:
  ret void

unreachable:
  cleanuppad within none []
  unreachable
}

;; Debug info (from test12)

; Make sure the DISubprogram doesn't get cloned
; CHECK-LABEL: !llvm.module.flags
; CHECK-NOT: !DISubprogram
; CHECK: !{{[0-9]+}} = distinct !DISubprogram(name: "test12"
; CHECK-NOT: !DISubprogram
!llvm.module.flags = !{!0}
!llvm.dbg.cu = !{!1}

!0 = !{i32 2, !"Debug Info Version", i32 3}
!1 = distinct !DICompileUnit(language: DW_LANG_C_plus_plus, file: !2, producer: "compiler", isOptimized: false, runtimeVersion: 0, emissionKind: 1, enums: !3, subprograms: !4)
!2 = !DIFile(filename: "test.cpp", directory: ".")
!3 = !{}
!4 = !{!5}
!5 = distinct !DISubprogram(name: "test12", scope: !2, file: !2, type: !6, isLocal: false, isDefinition: true, scopeLine: 3, flags: DIFlagPrototyped, isOptimized: true, variables: !3)
!6 = !DISubroutineType(types: !7)
!7 = !{null}
!8 = !DILocation(line: 1, scope: !5)
!9 = !DILocation(line: 2, scope: !5)
