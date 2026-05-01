import 'package:flutter/material.dart';

class BreadcrumbBar extends StatelessWidget {
  final String path;
  const BreadcrumbBar({super.key, required this.path});

  @override
  Widget build(BuildContext context) {
    final segments = path.split('/').where((s) => s.isNotEmpty).toList();

    return Container(
      height: 36,
      color: Colors.black26,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        itemCount: segments.length,
        separatorBuilder: (_, __) => const Icon(
          Icons.chevron_right,
          size: 16,
          color: Colors.white38,
        ),
        itemBuilder: (context, index) {
          return Center(
            child: Text(
              segments[index],
              style: TextStyle(
                fontSize: 12,
                color: index == segments.length - 1
                    ? Colors.white
                    : Colors.white54,
              ),
            ),
          );
        },
      ),
    );
  }
}
