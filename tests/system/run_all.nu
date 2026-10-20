# tests/system/run_all.nu
use test_stage0.nu
use test_stage1.nu
use test_hermeticity.nu

def main [] {
    print "\n========================================================"
    print "         ClauseOS Systems Verification Suite            "
    print "========================================================\n"

    test_stage0
    test_stage1
    test_hermeticity

    print "\n========================================================"
    print "  🎉 ALL SYSTEM ASSERTIONS PASSED SUCCESSFULLY          "
    print "========================================================\n"
}