use ($nu.default-config-dir | path join mise.nu)

# config/shell/config.nu
$env.config = {
    show_banner: false
    table: {
        mode: rounded
    }
}