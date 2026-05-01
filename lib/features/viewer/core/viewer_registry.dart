import 'viewer_plugin.dart';

class ViewerRegistry {
  static final List<ViewerPlugin> _plugins = [];

  /// Register a viewer plugin. Higher-priority plugins are matched first.
  static void register(ViewerPlugin plugin) {
    _plugins.add(plugin);
    _plugins.sort((a, b) => b.priority.compareTo(a.priority));
  }

  /// Returns the best plugin able to handle [path], or null if none.
  static ViewerPlugin? getPlugin(String path) {
    for (final plugin in _plugins) {
      if (plugin.canHandle(path)) return plugin;
    }
    return null;
  }

  /// Debug: list all registered plugin IDs.
  static List<String> listPlugins() => _plugins.map((e) => e.id).toList();

  /// Unregister a plugin by ID.
  static void unregister(String id) {
    _plugins.removeWhere((p) => p.id == id);
  }
}
