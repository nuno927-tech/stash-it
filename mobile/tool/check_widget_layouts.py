"""Everything about the widgets that no compiler checks.

    python3 tool/check_widget_layouts.py

Home screen widgets are assembled across four languages that never see each
other: Dart writes a payload, Kotlin reads it, XML declares the views, and the
LAUNCHER inflates them in its own process. Almost every mistake in that chain
compiles cleanly and then shows up as a blank widget with no error anywhere.

Four of them are checked here.

  1. A view class RemoteViews cannot inflate. The allowlist is short and does
     not include <View>, ConstraintLayout, or anything custom. The launcher
     rejects it and the home screen says "An error occurred when loading
     widget", which is the whole message.

  2. A ?theme/attribute. It asks the LAUNCHER's theme, not this app's, and
     fails the same silent way.

  3. An R.id the provider reaches for that its layout does not define. Kotlin
     compiles because the id exists SOMEWHERE in the app's R class — just not
     in the layout being inflated — and setTextViewText on it does nothing.

  4. A SharedPreferences key that Dart writes and Kotlin does not read, or the
     reverse. Nothing anywhere connects those two strings; a rename on one side
     is a widget that quietly stops updating.
"""

import pathlib
import re
import sys
import xml.etree.ElementTree as ET

# android.widget.RemoteViews's @RemoteView classes, plus the layouts it allows.
ALLOWED = {
    'FrameLayout', 'LinearLayout', 'RelativeLayout', 'GridLayout',
    'AnalogClock', 'Button', 'Chronometer', 'ImageButton', 'ImageView',
    'ProgressBar', 'TextView', 'ViewFlipper', 'ListView', 'GridView',
    'StackView', 'AdapterViewFlipper', 'ViewStub',
}

RES = pathlib.Path('android/app/src/main/res')
KOTLIN = pathlib.Path('android/app/src/main/kotlin/app/stashit')
MIRROR = pathlib.Path('lib/io/widget_mirror.dart')

# Which provider draws which layout. The only place that pairing is written
# down outside the RemoteViews constructor call itself.
PROVIDERS = {
    'QuickAddWidget.kt': 'widget_quick_add',
    'RingWidget.kt': 'widget_ring',
    'ComingUpWidget.kt': 'widget_coming_up',
}


def layouts(problems: list[str]) -> None:
    for path in sorted((RES / 'layout').glob('widget_*.xml')):
        root = ET.parse(path).getroot()

        for element in root.iter():
            if not isinstance(element.tag, str):
                continue

            if element.tag not in ALLOWED:
                problems.append(
                    f'{path.name}: <{element.tag}> is not a view RemoteViews '
                    f'can inflate')

            for name, value in element.attrib.items():
                if value.startswith('?'):
                    problems.append(
                        f'{path.name}: {name}="{value}" asks the launcher\'s '
                        f'theme, not ours')

        print(f'  {path.name}: {len(list(root.iter()))} views')


def ids(problems: list[str]) -> None:
    for provider, layout in PROVIDERS.items():
        source = (KOTLIN / provider).read_text(encoding='utf-8')
        markup = (RES / 'layout' / f'{layout}.xml').read_text(encoding='utf-8')

        wanted = set(re.findall(r'R\.id\.(\w+)', source))
        declared = set(re.findall(r'@\+id/(\w+)', markup))

        for missing in sorted(wanted - declared):
            problems.append(
                f'{provider}: R.id.{missing} is not in {layout}.xml')

        print(f'  {provider}: {len(wanted)} ids, all in {layout}.xml'
              if not wanted - declared else f'  {provider}: ids MISSING')


def keys(problems: list[str]) -> None:
    dart = MIRROR.read_text(encoding='utf-8')

    for provider in PROVIDERS:
        source = (KOTLIN / provider).read_text(encoding='utf-8')

        # Only the constants NAMED as keys. Quick add's ADD_ITEM and friends
        # are words that travel in an Intent, not entries in the shared
        # preferences the mirror writes, and matching every string constant
        # would report all three of them forever.
        for key in re.findall(r'const val (?:KEY\w*) = "([a-z_]+)"', source):
            if f"'{key}'" not in dart:
                problems.append(
                    f'{provider}: reads "{key}", which widget_mirror.dart '
                    f'never writes')


def main() -> int:
    problems: list[str] = []

    layouts(problems)
    ids(problems)
    keys(problems)

    if problems:
        print()
        for problem in problems:
            print(f'  {problem}')
        return 1

    print('  nothing a launcher would refuse, and both sides agree')
    return 0


if __name__ == '__main__':
    sys.exit(main())
