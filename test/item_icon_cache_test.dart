import 'package:flutter_test/flutter_test.dart';
import 'package:poe2_loot_tracker/item_icon_cache.dart';

void main() {
  test('uses a stable distinct cache file for each icon URL', () {
    final first = ItemIconCache.cacheFileFor(
      Uri.parse('https://web.poecdn.com/gen/image/first.png'),
    );
    final repeat = ItemIconCache.cacheFileFor(
      Uri.parse('https://web.poecdn.com/gen/image/first.png'),
    );
    final second = ItemIconCache.cacheFileFor(
      Uri.parse('https://web.poecdn.com/gen/image/second.png'),
    );

    expect(first.path, repeat.path);
    expect(first.path, isNot(second.path));
    expect(first.path, endsWith('.img'));
    expect(
      first.parent.path,
      endsWith(
        'cache${ItemIconCache.cacheDirectory.path.contains('\\') ? '\\' : '/'}item-icons',
      ),
    );
  });
}
