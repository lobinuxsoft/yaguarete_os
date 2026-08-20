# YaguareteOS — local AI for Zed: inference server, model and editor wiring.
#
# Zed's AI panel speaks to any OpenAI-compatible endpoint. This recipe puts
# one on 127.0.0.1, so the assistant answers from the user's own GPU with
# nothing leaving the machine.
#
# Why a container and not a binary: llama.cpp ships no RPM and the image is
# immutable, so layering it would mean rebuilding on every upstream release.
# The official ghcr.io/ggml-org/llama.cpp:server-vulkan image is rebuilt on
# every commit and carries the Vulkan backend already linked, which matters
# here — a llama.cpp older than the model's architecture fails to load with
# an unhelpful error, and Qwen3.5 (arch "qwen35") is recent enough to hit
# exactly that.
#
# Why Vulkan and not ROCm: Vulkan needs only /dev/dri and works across the
# RDNA generations this distro targets, including the handheld APUs. ROCm
# would be faster on the desktop cards and unavailable on half the fleet.
#
# The model is chosen by device class, because the same file is a good
# default on a 16 GB desktop card and a bad one on a handheld sharing GTT
# with the game:
#
#   desktop   Qwen3.5-9B  UD-Q4_K_XL   ~6.0 GB on disk, ~9 GB VRAM at 32k
#   handheld  Qwen3.5-4B  UD-Q4_K_XL   ~2.6 GB on disk, ~4 GB VRAM at 16k
#
# Both have reasoning disabled at the server (--reasoning off). Qwen3.5
# thinks by default, and a thinking model inside an editor spends its whole
# token budget deliberating before it writes anything.
#
# Everything lands in $HOME: model under ~/.local/share/yaguarete/models,
# a systemd --user unit, and a merge into Zed's settings. No image layer,
# no root, no reboot.

_local_ai_image := "ghcr.io/ggml-org/llama.cpp:server-vulkan"
_local_ai_port := "8100"
_local_ai_alias := "yaguarete-local"
_local_ai_repo_desktop := "unsloth/Qwen3.5-9B-GGUF"
_local_ai_file_desktop := "Qwen3.5-9B-UD-Q4_K_XL.gguf"
_local_ai_ctx_desktop := "32768"
_local_ai_repo_handheld := "unsloth/Qwen3.5-4B-GGUF"
_local_ai_file_handheld := "Qwen3.5-4B-UD-Q4_K_XL.gguf"
_local_ai_ctx_handheld := "16384"

# Local AI for Zed — llama.cpp server + model, per-user (install | status | remove)
[group("yaguarete")]
yaguarete-setup-local-ai ACTION="":
    #!/usr/bin/bash
    set -euo pipefail
    source /usr/libexec/yaguarete/emu-helpers.sh

    model_dir="$HOME/.local/share/yaguarete/models"
    unit_dir="$HOME/.config/systemd/user"
    unit="$unit_dir/yaguarete-local-ai.service"
    zed_settings="$HOME/.var/app/dev.zed.Zed/config/zed/settings.json"

    if yg_is_handheld; then
        repo="{{ _local_ai_repo_handheld }}"; file="{{ _local_ai_file_handheld }}"
        ctx="{{ _local_ai_ctx_handheld }}"; klass="handheld"
    else
        repo="{{ _local_ai_repo_desktop }}"; file="{{ _local_ai_file_desktop }}"
        ctx="{{ _local_ai_ctx_desktop }}"; klass="desktop"
    fi

    action="$ACTION"
    if [[ -z "$action" ]]; then
        echo "Usage: ujust yaguarete-setup-local-ai [install|status|remove]"
        exit 0
    fi

    case "$action" in
      status)
        [[ -f "$model_dir/$file" ]] \
            && yg_ok "Model present: $file ($(du -h "$model_dir/$file" | cut -f1))" \
            || yg_warn "Model missing: $file"
        systemctl --user is-enabled yaguarete-local-ai.service >/dev/null 2>&1 \
            && yg_ok "Service enabled." || yg_warn "Service not enabled."
        if curl -sf "http://127.0.0.1:{{ _local_ai_port }}/health" >/dev/null 2>&1; then
            yg_ok "Server answering on 127.0.0.1:{{ _local_ai_port }}."
        else
            yg_warn "Server not answering on 127.0.0.1:{{ _local_ai_port }}."
        fi
        # The Portal reads this word to pick which button to show.
        [[ -f "$model_dir/$file" ]] && echo "install" || echo "remove"
        ;;

      install)
        yg_info "Local AI — install ($klass profile)"
        if [[ "$(id -u)" -eq 0 ]]; then
            yg_err "Do not run this as root: everything installs into your own \$HOME."
            exit 1
        fi
        yg_check_internet

        if ! flatpak info --system dev.zed.Zed >/dev/null 2>&1 \
           && ! flatpak info --user dev.zed.Zed >/dev/null 2>&1; then
            yg_warn "Zed is not installed. The server will still work for any"
            yg_warn "OpenAI-compatible client; install Zed from the Portal to use it there."
        fi

        if [[ ! -e /dev/dri/renderD128 ]]; then
            yg_err "No /dev/dri render node. The Vulkan backend needs one."
            exit 1
        fi

        # The model is the big cost; check for it before pulling anything.
        if [[ -f "$model_dir/$file" ]]; then
            yg_ok "Model already downloaded — skipping."
        else
            yg_check_disk 9000
            echo
            yg_info "About to download $file from $repo."
            yg_info "This is a multi-gigabyte download over your connection."
            yg_confirm "Continue?" || exit 0
            mkdir -p "$model_dir"
            yg_download "https://huggingface.co/$repo/resolve/main/$file" "$model_dir/$file.part"
            mv "$model_dir/$file.part" "$model_dir/$file"
        fi

        yg_info "Pulling the inference server image (once, then cached)."
        podman pull "{{ _local_ai_image }}"

        mkdir -p "$unit_dir"
        cat > "$unit" <<UNIT
    [Unit]
    Description=YaguareteOS local AI (llama.cpp, Vulkan) for Zed
    After=network-online.target

    [Service]
    Type=simple
    ExecStart=/usr/bin/podman run --rm --name yaguarete-local-ai \\
        --device /dev/dri --network host \\
        -v %h/.local/share/yaguarete/models:/models:ro,z \\
        {{ _local_ai_image }} \\
        -m /models/$file -a {{ _local_ai_alias }} \\
        -ngl 99 -c $ctx --reasoning off --jinja \\
        --host 127.0.0.1 --port {{ _local_ai_port }}
    ExecStop=/usr/bin/podman stop -t 10 yaguarete-local-ai
    Restart=on-failure

    [Install]
    WantedBy=default.target
    UNIT
        sed -i 's/^    //' "$unit"

        systemctl --user daemon-reload
        systemctl --user enable --now yaguarete-local-ai.service

        # Zed's settings are the user's: merge our provider in, never overwrite
        # the file. A first-run Zed has themes and keymaps in here already.
        mkdir -p "$(dirname "$zed_settings")"
        # just keeps the heredoc indented; strip it before Python sees it.
        sed 's/^    //' <<'PY' | python3 - "$zed_settings" "$ctx"
    import json, sys, os
    path, ctx = sys.argv[1], int(sys.argv[2])
    data = {}
    if os.path.exists(path):
        try:
            data = json.load(open(path))
        except ValueError:
            os.replace(path, path + ".bak")
            print("  existing settings.json was not valid JSON — kept as settings.json.bak")
    lm = data.setdefault("language_models", {}).setdefault("llama.cpp", {})
    lm["api_url"] = "http://127.0.0.1:8100"
    lm["auto_discover"] = False
    lm["available_models"] = [{
        "name": "yaguarete-local",
        "display_name": "YaguareteOS local",
        "max_tokens": ctx,
        "supports_tools": True,
        "supports_images": False,
    }]
    # Only claim the default when the user has not picked one: a returning
    # user's choice outranks ours.
    agent = data.setdefault("agent", {})
    if not agent.get("default_model"):
        agent["default_model"] = {"provider": "llama.cpp", "model": "yaguarete-local"}
        print("  set as the default model")
    json.dump(data, open(path, "w"), indent=2)
    print("  Zed provider merged into", path)
    PY

        echo
        yg_ok "Local AI ready on http://127.0.0.1:{{ _local_ai_port }} (model: $file)."
        yg_info "In Zed, pick 'YaguareteOS local' from the model selector."
        yg_info "First load takes a moment while the weights reach the GPU."
        ;;

      remove)
        yg_info "Local AI — remove"
        systemctl --user disable --now yaguarete-local-ai.service 2>/dev/null || true
        rm -f "$unit"
        systemctl --user daemon-reload 2>/dev/null || true
        podman rmi "{{ _local_ai_image }}" 2>/dev/null || true
        if [[ -f "$model_dir/$file" ]]; then
            yg_warn "The model file is kept: $model_dir/$file"
            yg_warn "Delete it by hand if you want the disk space back."
        fi
        yg_info "Zed's settings were left untouched; remove the llama.cpp provider there if you want it gone."
        yg_ok "Removed."
        ;;

      *)
        yg_err "Unknown action: $action (expected install, status or remove)"
        exit 1
        ;;
    esac
