#!/bin/bash

source "$(dirname "${BASH_SOURCE[0]}")/base-test.sh"

require_command lua

# Run o.resize_width(px) against a stubbed Hyprland and print what it dispatched.
resize_width() {
  local layout="$1"
  local floating="$2"
  local px="$3"
  local direction="${4:-right}"
  local special="${5:-}"

  OMARCHY_PATH="$ROOT" LAYOUT="$layout" FLOATING="$floating" PX="$px" DIRECTION="$direction" SPECIAL="$special" lua <<'LUA'
package.path = os.getenv("OMARCHY_PATH") .. "/?.lua;" .. package.path

hl = {
  dsp = {
    layout = function(message)
      return "layout " .. message
    end,
    window = {
      resize = function(args)
        return string.format("resize x=%d y=%d relative=%s", args.x, args.y, tostring(args.relative))
      end,
    },
  },
  dispatch = function(dispatcher)
    print(dispatcher)
  end,
  get_active_window = function()
    return { floating = os.getenv("FLOATING") == "true" }
  end,
  get_active_workspace = function()
    return { tiled_layout = os.getenv("LAYOUT") }
  end,
  get_active_special_workspace = function()
    local special = os.getenv("SPECIAL")
    return special ~= "" and { tiled_layout = special } or nil
  end,
  get_config = function(key)
    if key == "scrolling.direction" then
      return os.getenv("DIRECTION")
    end
  end,
  -- 2880px at 1.25 is 2304 logical, less 104 reserved for a side panel.
  get_active_monitor = function()
    return { size = { width = 2880, height = 1800 }, scale = 1.25, transform = 0, reserved = { left = 104, right = 0 } }
  end,
}

require("default.hypr.helpers")
o.resize_width(tonumber(os.getenv("PX")))()
LUA
}

# The last column of a scrolling tape is clamped to the viewport by the generic
# resize, so scrolling workspaces size the column instead (omacom/omarchy#5101).
[[ $(resize_width scrolling false 100) == "layout colresize +0.0455" ]] ||
  fail "a scrolling column grows by its share of the usable width" "$(resize_width scrolling false 100)"
[[ $(resize_width scrolling false -300) == "layout colresize -0.1364" ]] ||
  fail "a scrolling column shrinks by its share of the usable width" "$(resize_width scrolling false -300)"
pass "a scrolling workspace resizes the column"

[[ $(resize_width dwindle false 100) == "resize x=100 y=0 relative=true" ]] ||
  fail "a dwindle window keeps the generic resize" "$(resize_width dwindle false 100)"
[[ $(resize_width master false -25) == "resize x=-25 y=0 relative=true" ]] ||
  fail "a master window keeps the generic resize" "$(resize_width master false -25)"
pass "other layouts keep the generic resize"

[[ $(resize_width scrolling true 100) == "resize x=100 y=0 relative=true" ]] ||
  fail "a floating window on a scrolling workspace keeps the generic resize" "$(resize_width scrolling true 100)"
pass "a floating window keeps the generic resize"

[[ $(resize_width scrolling false 100 down) == "resize x=100 y=0 relative=true" ]] ||
  fail "a vertical scrolling tape keeps the generic resize" "$(resize_width scrolling false 100 down)"
pass "a vertical scrolling tape keeps the generic resize"

# The scratchpad sits over the workspace beneath it, so its own layout decides.
[[ $(resize_width scrolling false 100 right dwindle) == "resize x=100 y=0 relative=true" ]] ||
  fail "a dwindle scratchpad over a scrolling workspace keeps the generic resize" "$(resize_width scrolling false 100 right dwindle)"
[[ $(resize_width dwindle false 100 right scrolling) == "layout colresize +0.0455" ]] ||
  fail "a scrolling scratchpad over a dwindle workspace resizes the column" "$(resize_width dwindle false 100 right scrolling)"
pass "an open scratchpad's layout decides the resize"
