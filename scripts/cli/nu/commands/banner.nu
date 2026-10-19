# scripts/console/nu/commands/banner.nu

export def main [] {
    let ascii_art = r#'
                                                            
 ,-----.,--.                               ,-----.  ,---.   
'  .--./|  | ,--,--.,--.,--. ,---.  ,---. '  .-.  ''   .-'  
|  |    |  |' ,-.  ||  ||  |(  .-' | .-. :|  | |  |`.  `-.  
'  '--'\|  |\ '-'  |'  ''  '.-'  `)\   --.'  '-'  '.-'    | 
 `-----'`--' `--`--' `----' `----'  `----' `-----' `-----'  
                                                            
'#
    let line = ("" | fill -c "=" -w 56)
    let root = ($env.CLAUSE_PROJECT_ROOT? | default ($env.PROJECT_ROOT? | default '.'))
    let nu_ver = ($nu.nushell-version? | default (version | get version? | default '0.x'))
    
    print $"(ansi cyan)($ascii_art)(ansi reset)"
    print $"(ansi dark_gray)($line)(ansi reset)"
    print $"  (ansi green_bold)ClauseOS Workbench(ansi reset) (ansi dark_gray)|(ansi reset) (ansi yellow)TIGAH Control Plane v0.1.0(ansi reset)"
    print $"  (ansi blue)Hermetic Root:(ansi reset) ($root)"
    print $"  (ansi blue)Interactive Shell:(ansi reset) Nushell ($nu_ver)"
    print $"(ansi dark_gray)($line)(ansi reset)\n"
}