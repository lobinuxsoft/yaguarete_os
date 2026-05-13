// OVERRIDE BY YAGUARETEOS — see issue #84 (bug A)
// Bazzite Vapor upstream sets icon = "distributor-logo-steamdeck" which the
// icon theme resolves to the "b" bbrew mark. Replace with the I1 Kickoff
// variant from Phase 3 cascade (_01, see project_yaguarete_os_next_session
// memory + issue #82).
// Absolute path bypasses icon theme search — explicit and stable across
// theme switches.
applet.currentConfigGroup = ["General"]
applet.writeConfig("icon", "/usr/share/yaguarete/branding/yaguarete_os_vector_01.svg")
applet.reloadConfig()
