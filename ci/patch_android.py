# Sets the app name and internet permission in the Android files Flutter generates.
import re, pathlib
m = pathlib.Path("android/app/src/main/AndroidManifest.xml")
s = m.read_text()
s = re.sub(r'android:label="[^"]*"', 'android:label="Lab Results Reader"', s, count=1)
if "android.permission.INTERNET" not in s:
    s = re.sub(r'(<manifest[^>]*>)', r'\1\n    <uses-permission android:name="android.permission.INTERNET" />', s, count=1)
if "TTS_SERVICE" not in s:
    s = s.replace("</manifest>", """    <queries>
        <intent>
            <action android:name="android.intent.action.TTS_SERVICE" />
        </intent>
    </queries>
</manifest>""")
m.write_text(s)
print(s[:600])
