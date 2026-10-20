def "parse vars" [] {
  $in | from csv --noheaders --no-infer | rename 'op' 'name' 'value'
}

def --env "update-env" [] {
  for $var in $in {
    if $var.op == "set" {
      if ($var.name =~ '(?i)^path$') {
        $env.PATH = ($var.value | split row (char esep))
      } else {
        load-env {($var.name): $var.value}
      }
    } else if $var.op == "hide" {
      try { hide-env $var.name }
    }
  }
}
export-env {
  $env.__MISE_ORIG_PATH = r#'M:\clause.os\.local\bin;C:\WINDOWS\system32;C:\WINDOWS;C:\WINDOWS\System32\Wbem;C:\WINDOWS\System32\WindowsPowerShell\v1.0\;C:\WINDOWS\System32\OpenSSH\;C:\Program Files\Git\cmd;C:\Program Files (x86)\Windows Kits\10\Windows Performance Toolkit\;C:\Users\Studio\AppData\Local\Microsoft\WindowsApps;C:\Users\Studio\AppData\Local\Programs\Ollama;C:\Users\Studio\AppData\Local\gitkraken\bin;'#
$env.Path = (r#'M:\clause.os\.cache\toolchain\mise\shims;M:\clause.os\.local\bin;C:\WINDOWS\system32;C:\WINDOWS;C:\WINDOWS\System32\Wbem;C:\WINDOWS\System32\WindowsPowerShell\v1.0\;C:\WINDOWS\System32\OpenSSH\;C:\Program Files\Git\cmd;C:\Program Files (x86)\Windows Kits\10\Windows Performance Toolkit\;C:\Users\Studio\AppData\Local\Microsoft\WindowsApps;C:\Users\Studio\AppData\Local\Programs\Ollama;C:\Users\Studio\AppData\Local\gitkraken\bin;'# | split row (char esep))

  '' | parse vars | update-env
  $env.MISE_SHELL = "nu"
  let mise_hook = {
    condition: { "MISE_SHELL" in $env }
    code: { mise_hook }
  }
  add-hook hooks.pre_prompt $mise_hook
  add-hook hooks.env_change.PWD $mise_hook
}

def --env add-hook [field: cell-path new_hook: any] {
  let field = $field | split cell-path | update optional true | into cell-path
  let old_config = $env.config? | default {}
  let old_hooks = $old_config | get $field | default []
  $env.config = ($old_config | upsert $field ($old_hooks ++ [$new_hook]))
}

export def --env --wrapped main [command?: string, --help, ...rest: string] {
  let commands = ["deactivate", "shell", "sh"]

  if ($command == null) {
    ^"M:\\clause.os\\.local\\bin\\mise.exe"
  } else if ($command == "activate") {
    $env.MISE_SHELL = "nu"
  } else if ($command in $commands) {
    ^"M:\\clause.os\\.local\\bin\\mise.exe" $command ...$rest
    | parse vars
    | update-env
  } else {
    ^"M:\\clause.os\\.local\\bin\\mise.exe" $command ...$rest
  }
}

def --env mise_hook [] {
  ^"M:\\clause.os\\.local\\bin\\mise.exe" hook-env -s nu
    | parse vars
    | update-env
}

