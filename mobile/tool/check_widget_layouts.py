"""What a launcher will refuse to inflate.

    python3 tool/check_widget_layouts.py

A widget layout is inflated by the LAUNCHER, in the launcher's process, from a
fixed allowlist of view classes and with the launcher's theme. Two mistakes
follow from that and neither is caught by the Android build:

    a view class outside the allowlist — <View>, ConstraintLayout, anything
    custom — which the build compiles happily and the launcher rejects

    a ?theme/attribute reference, which asks the launcher's theme rather than
    this app's

Both give the same useless message on the home screen: "An error occurred when
loading widget". So they are checked here instead, where the message can say
which line.
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
    'StackView', 'AdapterViewFlipper', 'ViewStub', 'Space',
}

LAYOUTS = pathlib.Path('android/app/src/main/res/layout')


def main() -> int:
    problems = []

    for path in sorted(LAYOUTS.glob('widget_*.xml')):
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

    if problems:
        print()
        for problem in problems:
            print(f'  {problem}')
        return 1

    print('  nothing a launcher would refuse')
    return 0


if __name__ == '__main__':
    sys.exit(main())
