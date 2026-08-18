.pragma library

// Nerd Font glyph lookup for Hyprland toplevels, matched against the window
// class first and the window title second.
//
// ORDER MATTERS. Title-specific rules have to sit above the generic browser
// class rules, otherwise an Amazon or YouTube tab in Firefox resolves to the
// Firefox icon instead of its own. `resolve()` keeps that working for browsers
// while stopping the same title rules from hijacking native apps -- see the
// comment there.
//
// Icon map adapted from the `saif.workspaces` plugin by Saif Omar (MIT).
var rules = [
  { pattern: "windows",                                                       icon: "" },
  { pattern: "ai.opencode.desktop|opencode",                                  icon: "" },
  { pattern: "org.jellyfin.JellyfinDesktop|jellyfin",                         icon: "󰼁" },
  { pattern: "chrome-claude.ai__-default|claude",                             icon: "󰭹" },
  { pattern: ".*amazon.*",                                                    icon: "󰸩" },
  { pattern: ".*github.*",                                                    icon: "󰊤" },
  { pattern: ".*figma.*",                                                     icon: "󰣙" },
  { pattern: ".*jira.*",                                                      icon: "󰗃" },
  { pattern: ".*youtube.*",                                                   icon: "󰗃" },
  { pattern: ".*reddit.*",                                                    icon: "󰑍" },
  { pattern: ".*facebook.*",                                                  icon: "󰈎" },
  { pattern: ".*messenger.*",                                                 icon: "󰈎" },
  { pattern: ".*whatsapp.*",                                                  icon: "󰖣" },
  { pattern: ".*zapzap.*",                                                    icon: "󰖣" },
  { pattern: ".*gmail.*",                                                     icon: "󰊫" },
  { pattern: ".*proton.*mail.*",                                              icon: "󰊫" },
  { pattern: ".*ChatGPT.*",                                                   icon: "󰭹" },
  { pattern: ".*deepseek.*",                                                  icon: "󰭹" },
  { pattern: ".*qwen.*",                                                      icon: "󰭹" },
  { pattern: ".*Monkeytype.*",                                                icon: "󰌌" },
  { pattern: ".*Picture-in-Picture.*",                                        icon: "󰐹" },
  { pattern: "brave-x.com.*",                                                 icon: "󰕄" },
  { pattern: "brave-mail.proton.me.*",                                        icon: "󰊫" },
  { pattern: "twitter-x",                                                     icon: "󰕄" },

  // Browsers
  { pattern: "firefox|org.mozilla.firefox|librewolf|floorp|mercury-browser|[Cc]achy-browser", icon: "󰈹" },
  { pattern: "zen",                                                           icon: "󰈹" },
  { pattern: "waterfox|waterfox-bin",                                         icon: "󰈹" },
  { pattern: "microsoft-edge",                                                icon: "󰇩" },
  { pattern: "brave-browser|Brave-browser|Brave|brave",                       icon: "" },
  { pattern: "tor browser",                                                   icon: "󰖂" },
  { pattern: "Chromium|Thorium|[Cc]hrome",                                    icon: "󰊯" },

  // Chat & mail
  { pattern: "signal",                                                        icon: "󰍡" },
  { pattern: "[Tt]elegram-desktop|org.telegram.desktop|io.github.tdesktop_x64.TDesktop", icon: "󰘦" },
  { pattern: "discord|[Ww]ebcord|Vesktop",                                    icon: "󰙯" },
  { pattern: "slack",                                                         icon: "󰒱" },
  { pattern: "[Tt]hunderbird|[Tt]hunderbird-esr",                             icon: "󰇮" },
  { pattern: "eu.betterbird.Betterbird",                                      icon: "󰇮" },
  { pattern: "claws-mail",                                                    icon: "󰇮" },
  { pattern: "org.gnome.Evolution",                                           icon: "󰊫" },
  { pattern: "org.gnome.Geary",                                               icon: "󰊫" },
  { pattern: "Zoom",                                                          icon: "󰕧" },

  // Terminals & editors
  { pattern: ".*n?vim.*",                                                     icon: "" },
  { pattern: "konsole",                                                       icon: "󰆍" },
  { pattern: "foot",                                                          icon: "󰆍" },
  { pattern: "kitty",                                                         icon: "󰆍" },
  { pattern: "alacritty",                                                     icon: "󰆍" },
  { pattern: "com.mitchellh.ghostty",                                         icon: "󰊠" },
  { pattern: "org.wezfurlong.wezterm",                                        icon: "󰆍" },
  { pattern: "VSCode|code-url-handler|code-oss|codium|codium-url-handler|VSCodium|code|Code", icon: "󰨞" },
  { pattern: "dev.zed.Zed|dev.zed.Zed-Preview",                               icon: "󱓞" },
  { pattern: "subl",                                                          icon: "󰅳" },
  { pattern: "codeblocks",                                                    icon: "󰅩" },
  { pattern: "geany",                                                         icon: "󰅩" },
  { pattern: "jetbrains-idea",                                                icon: "󰅩" },
  { pattern: "android-studio",                                                icon: "󰀴" },
  { pattern: "mousepad",                                                      icon: "󰇾" },
  { pattern: "ghostwriter|org.kde.ghostwriter",                               icon: "󰷈" },
  { pattern: "org.gnome.TextEditor",                                          icon: "󰷈" },

  // Office & docs
  { pattern: "libreoffice-writer",                                            icon: "󰈙" },
  { pattern: "libreoffice-calc",                                              icon: "󰧷" },
  { pattern: "libreoffice-startcenter",                                       icon: "󰏆" },
  { pattern: "org.pwmt.zathura",                                              icon: "󰈦" },
  { pattern: "org.gnome.Contacts",                                            icon: "󰀉" },

  // Media
  { pattern: "mpv",                                                           icon: "󰐹" },
  { pattern: "celluloid",                                                     icon: "󰐹" },
  { pattern: "vlc",                                                           icon: "󰕼" },
  { pattern: ".*cmus.*",                                                      icon: "󰝚" },
  { pattern: "[Ss]potify",                                                    icon: "󰓇" },
  { pattern: "org.kde.elisa",                                                 icon: "󰝚" },
  { pattern: "org.gnome.Lollypop",                                            icon: "󰝚" },
  { pattern: "org.gnome.[Mm]usic",                                            icon: "󰝚" },
  { pattern: "rhythmbox",                                                     icon: "󰝚" },
  { pattern: "Cider",                                                         icon: "󰎆" },
  { pattern: "obs|com.obsproject.Studio",                                     icon: "󰐍" },
  { pattern: "gimp",                                                          icon: "󰏘" },

  // System & tools
  { pattern: "cake_wallet",                                                   icon: "󰠓" },
  { pattern: "feather",                                                       icon: "󰠓" },
  { pattern: "Exodus|exodus",                                                 icon: "󰠓" },
  { pattern: "com.transmissionbt.transmission.*",                             icon: "󰄠" },
  { pattern: "de.haeckerfelix.Fragments",                                     icon: "󰄠" },
  { pattern: "virt-manager|.virt-manager-wrapped|virtualbox manager|virtualbox", icon: "󰍺" },
  { pattern: "remmina",                                                       icon: "󰢹" },
  { pattern: "polkit-gnome-authentication-agent-1",                           icon: "󰒃" },
  { pattern: "nwg-look",                                                      icon: "󰔡" },
  { pattern: "[Pp]avucontrol|org.pulseaudio.pavucontrol",                     icon: "󰓃" },
  { pattern: "org.pipewire.Helvum",                                           icon: "󰓃" },
  { pattern: "Gparted",                                                       icon: "󰋊" },
  { pattern: "thunar|nemo",                                                   icon: "󰝰" },
  { pattern: "org.gnome.Nautilus|nautilus",                                   icon: "󰝰" },
  { pattern: "steam",                                                         icon: "󰓓" },
  { pattern: "emulator",                                                      icon: "󰄭" },
  { pattern: "PrusaSlicer|UltiMaker-Cura|OrcaSlicer",                         icon: "󰐫" }
]

var fallback = "󰘔"

// Classes that host something else and report it in the title: browsers show
// the page, terminals show the running program. For these the title is the
// better signal, so it is matched before the (generic) class rule. Every other
// class describes the app itself and is matched first.
var hostClasses = new RegExp(
  "^(firefox|org\\.mozilla\\.firefox|librewolf|floorp|mercury-browser|[Cc]achy-browser"
  + "|zen|waterfox|waterfox-bin|microsoft-edge|brave|brave-browser|Brave|Brave-browser"
  + "|Chromium|Thorium|[Cc]hrome|chrome-.*|tor browser"
  + "|konsole|foot|kitty|[Aa]lacritty|com\\.mitchellh\\.ghostty"
  + "|org\\.wezfurlong\\.wezterm)$", "i")

// Rules are compiled once per QML engine rather than per render. `.pragma
// library` means one shared copy across all three bar instances.
var compiled = null

function patterns() {
  if (compiled) return compiled
  compiled = []
  for (var i = 0; i < rules.length; i++) {
    compiled.push({ re: new RegExp(rules[i].pattern, "i"), icon: rules[i].icon })
  }
  return compiled
}

// Browser titles churn constantly, so the cache is capped and dropped wholesale
// once it grows past the limit instead of tracking per-entry age.
var cache = {}
var cacheCount = 0
var cacheLimit = 500

function resolve(cls, title) {
  var key = cls + "" + title
  var hit = cache[key]
  if (hit !== undefined) return hit

  var set = patterns()
  var isHost = hostClasses.test(cls)

  // Matching title and class in a single pass lets a title rule win over the
  // window's own class: a Slack channel called "tech-log-github-pr" resolves to
  // the GitHub icon because `.*github.*` is tested long before `slack`.
  //
  // For an app that is not hosting anything, the class is authoritative, so it
  // is matched on its own first. Hosts are excluded from that pass -- their
  // class is a generic browser/terminal rule, and letting it win would undo the
  // site and `nvim` rules entirely.
  var icon = fallback
  var i
  if (!isHost) {
    for (i = 0; i < set.length; i++) {
      if (set[i].re.test(cls)) { icon = set[i].icon; break }
    }
  }

  // Title next (site/program rules for hosts, and a useful fallback for
  // anything whose class did not match), then the host's own class last.
  if (icon === fallback) {
    for (i = 0; i < set.length; i++) {
      if (set[i].re.test(title)) { icon = set[i].icon; break }
    }
  }
  if (icon === fallback && isHost) {
    for (i = 0; i < set.length; i++) {
      if (set[i].re.test(cls)) { icon = set[i].icon; break }
    }
  }

  if (cacheCount >= cacheLimit) {
    cache = {}
    cacheCount = 0
  }
  cache[key] = icon
  cacheCount++
  return icon
}
