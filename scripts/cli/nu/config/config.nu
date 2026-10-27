# scripts/cli/nu/config/config.nu - ClauseOS Nushell UI & Shell Overlay Config
use mise.nu

$env.config = {
    show_banner: false
    table: {
        mode: rounded
    }
}