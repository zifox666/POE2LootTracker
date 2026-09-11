#ifndef RUNNER_OVERLAY_INTERACTION_PLUGIN_H_
#define RUNNER_OVERLAY_INTERACTION_PLUGIN_H_

#include <flutter/plugin_registry.h>

// Registers the runner-owned channel on the supplied Flutter engine. This is called for the main
// engine and every desktop_multi_window child engine.
void RegisterOverlayInteractionPlugin(flutter::PluginRegistry* registry);

#endif  // RUNNER_OVERLAY_INTERACTION_PLUGIN_H_
